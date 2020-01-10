package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"time"

	"go.uber.org/zap"
)

var listenAddr string

func main() {
	// Check env for listenAddr, default to ":5000"
	listenAddr, listenAddrSet := os.LookupEnv("TINYBABY_LISTEN_ADDR")
	if !listenAddrSet {
		listenAddr = ":5000"
	}

	// Setup logger and ensure buffer gets flushed
	logger, err := zap.NewProduction()
	if err != nil {
		logger.Fatal("Failed to initialize zap logger",
			zap.String("err", err.Error()),
		)
	}
	defer logger.Sync()

	logger.Info("Server is starting")

	router := http.NewServeMux()
	router.Handle("/", index())

	server := &http.Server{
		Addr:         listenAddr,
		Handler:      logging(logger)(router),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  15 * time.Second,
	}

	done := make(chan bool)
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt)

	go func() {
		<-quit
		logger.Info("Server is shutting down")

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		server.SetKeepAlivesEnabled(false)
		if err := server.Shutdown(ctx); err != nil {
			logger.Fatal("Could not gracefully shutdown the server",
				zap.Error(err),
			)
		}
		close(done)
	}()

	logger.Info("Server is ready to handle requests",
		zap.String("addr", listenAddr),
	)

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Fatal("Could not listen on address",
			zap.String("listenAdd", listenAddr),
			zap.Error(err),
		)
	}

	<-done
	logger.Info("Server stopped")
}

func index() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.WriteHeader(http.StatusOK)
	})
}

func logging(logger *zap.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				logger.Info("Handled request",
					zap.String("method", r.Method),
					zap.String("path", r.URL.Path),
					zap.String("remoteaddr", r.RemoteAddr),
					zap.String("useragent", r.UserAgent()),
				)
			}()
			next.ServeHTTP(w, r)
		})
	}
}
