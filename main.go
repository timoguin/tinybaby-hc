package main

import (
    "context"
    //"flag"
    "fmt"
    //"log"
    //"zap"
    "net/http"
    "os"
    "os/signal"
    //"sync/atomic"
    "time"

    "go.uber.org/zap"
)

//var (
//    listenAddr string
//)

func main() {
    port, portIsSet := os.LookupEnv("TINY_BABY_PORT")
    if !portIsSet {
            port = "80"
    }

    listenAddr := fmt.Sprintf(":%s", port)

//    flag.StringVar(&listenAddr, "listen-addr", ":5000", "server listen address")
//    flag.Parse()

    zapLogger, _ := zap.NewProduction()
    defer zapLogger.Sync() // flushes buffer, if any
    logger := zapLogger.Sugar()
    
    logger.Info("Server is starting...")

    router := http.NewServeMux()
    router.Handle("/", index())

//    nextRequestID := func() string {
//        return fmt.Sprintf("%d", time.Now().UnixNano())
//    }

    server := &http.Server{
        Addr:         listenAddr,
        Handler:      logging(logger)(router),
        //ErrorLog:     logger,
        ReadTimeout:  5 * time.Second,
        WriteTimeout: 10 * time.Second,
        IdleTimeout:  15 * time.Second,
    }

    done := make(chan bool)
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, os.Interrupt)

    go func() {
        <-quit
        logger.Info("Server is shutting down...")

        ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
        defer cancel()

        server.SetKeepAlivesEnabled(false)
        if err := server.Shutdown(ctx); err != nil {
            logger.Fatal("Could not gracefully shutdown the server", "err", err)
        }
        close(done)
    }()

    logger.Info("Server is ready to handle requests", "addr", listenAddr)
    if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
        logger.Fatalf("Could not listen on %s: %v\n", listenAddr, "err", err)
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
        fmt.Fprintln(w, "OK")
    })
}

func logging(logger *zap.SugaredLogger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            defer func() {
                logger.Infow("Got 'em",
                    "method", r.Method,
                    "path", r.URL.Path,
                    "remoteaddr", r.RemoteAddr,
                    "useragent", r.UserAgent(),
                )
            }()
            next.ServeHTTP(w, r)
        })
    }
}
