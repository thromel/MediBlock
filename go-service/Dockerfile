FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum first to leverage Docker cache
COPY go.mod go.sum ./
RUN go mod download

# Copy the source code
COPY . .

# Build the Go application
RUN go build -o main .

# Use a smaller image for the final container
FROM alpine:3.18

WORKDIR /app

# Install necessary dependencies
RUN apk --no-cache add ca-certificates

# Copy the binary from the builder stage
COPY --from=builder /app/main /app/

# Expose port
EXPOSE 8081

# Run the application
CMD ["/app/main"] 