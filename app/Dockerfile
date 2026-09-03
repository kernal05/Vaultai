# NOTE: drop your existing status-craft app source (from the earlier build)
# into this app/ directory so this Dockerfile has package.json, src/, etc.
# to build against.

FROM node:20-alpine@sha256:2d07db07a2df6830718ae2a47db6fedce6745db068d5efa73ba2cd822f84b57 AS build
WORKDIR /build
COPY app/package*.json ./
RUN npm ci
COPY app/ .
RUN npm run build

FROM nginx:1.27-alpine@sha256:d67ea0d64d518b1bb04acde3b00f722ac3e9764b3209a9b0a98924ba35e4b779
COPY --from=build /build/dist /usr/share/nginx/html
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
