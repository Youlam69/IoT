# The build stage runs natively and cross-compiles, so amd64 and arm64
# both build on one machine with no QEMU.
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
