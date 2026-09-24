FROM node:22-alpine AS build

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.29-alpine

LABEL org.opencontainers.image.source="https://github.com/rahmatfadhilah22/human-atlas"
LABEL org.opencontainers.image.description="Human Atlas interactive 3D anatomy explorer"
LABEL org.opencontainers.image.licenses="MIT"

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
