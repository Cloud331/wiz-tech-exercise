# Building the binary of the App
# First stage is a temp build environment
FROM golang:1.19 AS build

WORKDIR /go/src/tasky
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky

# Second stage is the actual deployed image
FROM alpine:3.17.0 as release

WORKDIR /app
COPY --from=build  /go/src/tasky/tasky .
COPY --from=build  /go/src/tasky/assets ./assets

#Place it into filesystem root to clearly separate from app code
COPY wizexercise.txt /wizexercise.txt

EXPOSE 8080
ENTRYPOINT ["/app/tasky"]


