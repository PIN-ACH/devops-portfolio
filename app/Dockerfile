# ---- Build stage ----------------------------------------------------------
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
# Install only production deps for a lean final image.
RUN npm ci --omit=dev

# ---- Runtime stage --------------------------------------------------------
FROM node:20-alpine
# Run as non-root for security.
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --chown=app:app . .
USER app
EXPOSE 3000
# Basic container healthcheck hitting the liveness probe.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -qO- http://localhost:3000/healthz || exit 1
CMD ["node", "src/server.js"]
