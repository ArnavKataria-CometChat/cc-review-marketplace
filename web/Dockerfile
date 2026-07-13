# ---- build stage ----
# The build compiles the app (tsc --noEmit + vite build). A type error here
# fails the image build, which is exactly the verify gate for this component.
FROM node:20-alpine AS build
WORKDIR /app

# Install dependencies against the lockfile first for better layer caching.
COPY package.json package-lock.json ./
RUN npm ci

# Build. VITE_API_BASE_URL is baked in at build time; override with
# `--build-arg VITE_API_BASE_URL=https://api.example.com`.
ARG VITE_API_BASE_URL=/api
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
COPY . .
RUN npm run build

# ---- runtime stage ----
# nginx serves the static bundle with SPA-friendly routing.
FROM nginx:1.27-alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
