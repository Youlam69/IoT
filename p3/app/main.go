// A minimal stand-in for wil42/playground: same JSON, same port, but built
// for arm64 as well as amd64. The version string is injected at build time.
package main

import (
	"fmt"
	"log"
	"net/http"
)

var version = "v1"

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, "{\"status\":\"ok\", \"message\": \"%s\"}\n", version)
	})

	log.Printf("playground %s listening on :8888", version)
	log.Fatal(http.ListenAndServe(":8888", nil))
}
