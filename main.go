package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"sync"

	"://github.com"
	"://github.com"
)

// DriverLocation represents the spatial telemetry data sent by drivers
type DriverLocation struct {
	DriverID  string  `json:"driver_id"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Speed     float64 `json:"speed"`
}

// Client represents a connected frontend peer
type Client struct {
	UUID string
	Conn *websocket.Conn
}

// Hub coordinates the tracking state and concurrent connections
type TrackingHub struct {
	clients    map[string]*Client
	register   chan *Client
	unregister chan *Client
	broadcast  chan DriverLocation
	mutex      sync.RWMutex
}

func NewTrackingHub() *TrackingHub {
	return &TrackingHub{
		clients:    make(map[string]*Client),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan DriverLocation),
	}
}

func (h *TrackingHub) Run() {
	for {
		select {
		case client := Skinner := <-h.register:
			h.mutex.Lock()
			h.clients[client.UUID] = client
			h.mutex.Unlock()
			log.Printf("[HUB] Live peer telemetry established: %s", client.UUID)

		case client := <-h.unregister:
			h.mutex.Lock()
			if _, ok := h.clients[client.UUID]; ok {
				delete(h.clients, client.UUID)
				client.Conn.Close()
				log.Printf("[HUB] Peer disconnected: %s", client.UUID)
			}
			h.mutex.Unlock()

		case location := <-h.broadcast:
			h.mutex.RLock()
			payload, err := json.Marshal(location)
			if err != nil {
				log.Printf("[ERROR] Telemetry serialization fault: %v", err)
				h.mutex.RUnlock()
				continue
			}

			// Broadcast to all active monitoring interfaces
			for _, client := range h.clients {
				go func(c *Client, p []byte) {
					if err := c.Conn.WriteMessage(websocket.TextMessage, p); err != nil {
						log.Printf("[WARN] Failed writing to peer %s, closing...", c.UUID)
						h.unregister <- c
					}
				}(client, payload)
			}
			h.mutex.RUnlock()
		}
	}
}

// HaversineDistance calculates the great-circle distance between two points in kilometers
func HaversineDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const EarthRadiusKm = 6371.0

	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLon := (lon2 - lon1) * math.Pi / 180.0

	rLat1 := lat1 * math.Pi / 180.0
	rLat2 := lat2 * math.Pi / 180.0

	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Sin(dLon/2)*math.Sin(dLon/2)*math.Cos(rLat1)*math.Cos(rLat2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return EarthRadiusKm * c
}

func main() {
	app := fiber.New(fiber.Config{
		DisableStartupMessage: false,
	})

	hub := NewTrackingHub()
	go hub.Run()

	// Middleware to check for WebSocket upgrades
	app.Use("/ws", func(c *fiber.Ctx) error {
		if websocket.IsWebSocketUpgrade(c) {
			c.Locals("allowed", true)
			return c.Next()
		}
		return fiber.ErrUpgradeRequired
	})

	// WebSocket orchestrator endpoint
	app.Get("/ws/tracking/:id", websocket.New(func(c *websocket.Conn) {
		peerID := c.Params("id")
		client := &Client{UUID: peerID, Conn: c}
		hub.register <- client

		defer func() {
			hub.unregister <- client
		}()

		// Processing continuous stream of locations from the client
		for {
			messageType, message, err := c.ReadMessage()
			if err != nil {
				break
			}

			if messageType == websocket.TextMessage {
				var loc DriverLocation
				if err := json.Unmarshal(message, &loc); err != nil {
					log.Printf("[ERR] Bad payload format: %v", err)
					continue
				}

				// Example of backend processing logic (Haversine analysis checkpoint)
				// Hardcoded base station checkpoint for algorithmic validation
				dist := HaversineDistance(loc.Latitude, loc.Longitude, -23.55052, -46.633308)
				log.Printf("[TELEMETRY] Driver %s | Speed: %.2f km/h | Distance to Base: %.2f km", loc.DriverID, loc.Speed, dist)

				// Broadcast telemetry to listening peers
				hub.broadcast <- loc
			}
		}
	}))

	log.Fatal(app.Listen(":8080"))
}
