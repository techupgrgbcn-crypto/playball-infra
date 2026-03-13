package main

import (
	"bufio"
	"embed"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

//go:embed templates/*
var templatesFS embed.FS

//go:embed static/*
//go:embed static/src/*
var staticFS embed.FS

//go:embed scripts/*.js
var scriptsFS embed.FS

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type TestConfig struct {
	Script         string  `json:"script"`
	Environment    string  `json:"environment"`
	Service        string  `json:"service"`
	VUs            int     `json:"vus"`
	Duration       string  `json:"duration"`
	TargetURL      string  `json:"targetUrl"`
	ThresholdP95   int     `json:"thresholdP95"`
	ThresholdError float64 `json:"thresholdError"`
}

type TestRunner struct {
	mu         sync.Mutex
	cmd        *exec.Cmd
	running    bool
	clients    map[*websocket.Conn]bool
	clientsMu  sync.RWMutex
	broadcast  chan string
}

var runner = &TestRunner{
	clients:   make(map[*websocket.Conn]bool),
	broadcast: make(chan string, 100),
}

func main() {
	go runner.broadcastMessages()

	http.HandleFunc("/", handleIndex)
	http.HandleFunc("/api/scripts", handleScripts)
	http.HandleFunc("/api/run", handleRun)
	http.HandleFunc("/api/stop", handleStop)
	http.HandleFunc("/api/status", handleStatus)
	http.HandleFunc("/ws", handleWebSocket)
	http.Handle("/static/", http.FileServer(http.FS(staticFS)))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("k6 Dashboard running on http://localhost:%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	tmpl, err := template.ParseFS(templatesFS, "templates/index.html")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	scripts := getAvailableScripts()
	data := map[string]interface{}{
		"Scripts": scripts,
		"Environments": []map[string]string{
			{"value": "dev", "label": "Development", "url": "https://dev.goormgb.com"},
			{"value": "staging", "label": "Staging", "url": "https://staging.goormgb.com"},
			{"value": "local", "label": "Local", "url": "http://localhost:8080"},
		},
	}

	tmpl.Execute(w, data)
}

func getAvailableScripts() []map[string]string {
	scripts := []map[string]string{}

	entries, err := scriptsFS.ReadDir("scripts")
	if err != nil {
		return scripts
	}

	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".js") {
			name := strings.TrimSuffix(entry.Name(), ".js")
			scripts = append(scripts, map[string]string{
				"file": entry.Name(),
				"name": name,
			})
		}
	}

	// Check scenarios subdirectory
	scenarioEntries, err := scriptsFS.ReadDir("scripts/scenarios")
	if err == nil {
		for _, entry := range scenarioEntries {
			if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".js") {
				name := "scenarios/" + strings.TrimSuffix(entry.Name(), ".js")
				scripts = append(scripts, map[string]string{
					"file": "scenarios/" + entry.Name(),
					"name": name,
				})
			}
		}
	}

	return scripts
}

func handleScripts(w http.ResponseWriter, r *http.Request) {
	scripts := getAvailableScripts()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(scripts)
}

func handleRun(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	runner.mu.Lock()
	if runner.running {
		runner.mu.Unlock()
		http.Error(w, "Test already running", http.StatusConflict)
		return
	}
	runner.mu.Unlock()

	var config TestConfig
	if err := json.NewDecoder(r.Body).Decode(&config); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	go runner.runTest(config)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "started"})
}

func handleStop(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	runner.mu.Lock()
	defer runner.mu.Unlock()

	if runner.cmd != nil && runner.cmd.Process != nil {
		runner.cmd.Process.Kill()
		runner.running = false
		runner.sendMessage("Test stopped by user")
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "stopped"})
}

func handleStatus(w http.ResponseWriter, r *http.Request) {
	runner.mu.Lock()
	running := runner.running
	runner.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"running": running})
}

func handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("WebSocket upgrade error:", err)
		return
	}

	runner.clientsMu.Lock()
	runner.clients[conn] = true
	runner.clientsMu.Unlock()

	defer func() {
		runner.clientsMu.Lock()
		delete(runner.clients, conn)
		runner.clientsMu.Unlock()
		conn.Close()
	}()

	// Keep connection alive
	for {
		_, _, err := conn.ReadMessage()
		if err != nil {
			break
		}
	}
}

func (tr *TestRunner) sendMessage(msg string) {
	select {
	case tr.broadcast <- msg:
	default:
		// Channel full, skip message
	}
}

func (tr *TestRunner) broadcastMessages() {
	for msg := range tr.broadcast {
		tr.clientsMu.RLock()
		for client := range tr.clients {
			err := client.WriteMessage(websocket.TextMessage, []byte(msg))
			if err != nil {
				client.Close()
				delete(tr.clients, client)
			}
		}
		tr.clientsMu.RUnlock()
	}
}

func (tr *TestRunner) runTest(config TestConfig) {
	tr.mu.Lock()
	tr.running = true
	tr.mu.Unlock()

	defer func() {
		tr.mu.Lock()
		tr.running = false
		tr.cmd = nil
		tr.mu.Unlock()
	}()

	// Extract script to temp file
	scriptPath := filepath.Join("scripts", config.Script)
	scriptContent, err := scriptsFS.ReadFile(scriptPath)
	if err != nil {
		tr.sendMessage(fmt.Sprintf("Error reading script: %v", err))
		return
	}

	tmpDir, err := os.MkdirTemp("", "k6-scripts")
	if err != nil {
		tr.sendMessage(fmt.Sprintf("Error creating temp dir: %v", err))
		return
	}
	defer os.RemoveAll(tmpDir)

	tmpScript := filepath.Join(tmpDir, filepath.Base(config.Script))
	if err := os.WriteFile(tmpScript, scriptContent, 0644); err != nil {
		tr.sendMessage(fmt.Sprintf("Error writing script: %v", err))
		return
	}

	// Build k6 command
	args := []string{
		"run",
		"-e", fmt.Sprintf("TARGET_URL=%s", config.TargetURL),
		"-e", fmt.Sprintf("ENVIRONMENT=%s", config.Environment),
		"-e", fmt.Sprintf("SERVICE=%s", config.Service),
		"-e", fmt.Sprintf("VUS=%d", config.VUs),
		"-e", fmt.Sprintf("DURATION=%s", config.Duration),
		"-e", fmt.Sprintf("THRESHOLD_P95=%d", config.ThresholdP95),
		"-e", fmt.Sprintf("THRESHOLD_ERROR=%.2f", config.ThresholdError),
		"--tag", fmt.Sprintf("testid=%s-%s-%d", config.Environment, config.Script, time.Now().Unix()),
		"--tag", fmt.Sprintf("environment=%s", config.Environment),
		"--tag", fmt.Sprintf("service=%s", config.Service),
	}

	// Add Prometheus output if available
	prometheusURL := os.Getenv("K6_PROMETHEUS_RW_SERVER_URL")
	if prometheusURL != "" {
		args = append(args, "--out", "experimental-prometheus-rw")
	}

	args = append(args, tmpScript)

	tr.sendMessage(fmt.Sprintf("$ k6 %s", strings.Join(args, " ")))
	tr.sendMessage("")

	tr.mu.Lock()
	tr.cmd = exec.Command("k6", args...)
	tr.mu.Unlock()

	stdout, _ := tr.cmd.StdoutPipe()
	stderr, _ := tr.cmd.StderrPipe()

	if err := tr.cmd.Start(); err != nil {
		tr.sendMessage(fmt.Sprintf("Error starting k6: %v", err))
		return
	}

	// Stream stdout
	go tr.streamOutput(stdout)
	go tr.streamOutput(stderr)

	tr.cmd.Wait()
	tr.sendMessage("")
	tr.sendMessage("Test completed")
}

func (tr *TestRunner) streamOutput(r io.Reader) {
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		tr.sendMessage(scanner.Text())
	}
}
