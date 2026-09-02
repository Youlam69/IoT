# The build stage runs on the host's own architecture ($BUILDPLATFORM) and
# cross-compiles for the target, so linux/amd64 and linux/arm64 both build on
# an arm64 machine with no QEMU involved.
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build
ARG TARGETARCH
ARG VERSION=v1
WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH \
    go build -ldflags "-s -w -X main.version=$VERSION" -o /playground .

FROM scratch
COPY --from=build /playground /playground
EXPOSE 8888
ENTRYPOINT ["/playground"]
