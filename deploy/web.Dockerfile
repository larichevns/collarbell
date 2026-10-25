# The web container: the landing (landing/, built with Astro), the owner's admin (admin/, React, under /admin/) and the
# web app for pet owners (web/, React, under /app/), served by nginx with the routes of the public address
# (nginx.conf). deploy/compose.yml builds it from the repository root.
FROM node:22-alpine AS landing
WORKDIR /landing
COPY landing/package.json landing/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY landing/ ./
RUN npm run build

FROM node:22-alpine AS admin
WORKDIR /admin
COPY admin/package.json admin/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY admin/ ./
RUN npm run build

FROM node:22-alpine AS web
WORKDIR /web
COPY web/package.json web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY web/ ./
RUN npm run build

FROM nginx:stable-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=landing /landing/dist/ /usr/share/nginx/html/
COPY --from=admin /admin/dist/ /usr/share/nginx/html/admin/
COPY --from=web /web/dist/ /usr/share/nginx/html/app/
