# ── Stage 1: Install deps & run tests ────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci                          # clean install (faster, deterministic)

COPY src/   ./src/
COPY tests/ ./tests/

# Tests run during the build — a broken build never makes it to production
RUN npm test

# ── Stage 2: Lean production image ───────────────────────────────────────
FROM node:18-alpine AS production

# Security: never run as root in a container
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Only copy what production needs
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
COPY package.json ./

USER appuser

EXPOSE 3000

# Kubernetes will call this URL to know the app is alive
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
