# Install dependencies only when needed
FROM node:alpine AS deps
WORKDIR /app
COPY package.json yarn.lock ./
COPY nextjs-docker-a/package.json ./nextjs-docker-a/
RUN yarn install --frozen-lockfile
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
# RUN apk add libc6-compat

# Rebuild the source code only when needed
FROM node:alpine AS builder
WORKDIR /app
COPY ./nextjs-docker-a ./nextjs-docker-a
COPY package.json yarn.lock ./
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/nextjs-docker-a/node_modules ./nextjs-docker-a/node_modules
RUN yarn workspace nextjs-docker-a build && yarn install --production --ignore-scripts --prefer-offline

# Production image, copy all the files and run next
FROM node:alpine AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# You only need to copy next.config.js if you are NOT using the default configuration
# COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/nextjs-docker-a/public ./nextjs-docker-a/public
COPY --from=builder --chown=nextjs:nodejs /app/nextjs-docker-a/.next ./nextjs-docker-a/.next
COPY --from=builder /app/nextjs-docker-a/node_modules ./nextjs-docker-a/node_modules
COPY --from=builder /app/nextjs-docker-a/package.json ./nextjs-docker-a/package.json

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

USER nextjs

EXPOSE 3000

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry.
# ENV NEXT_TELEMETRY_DISABLED 1

CMD ["yarn", "workspace", "nextjs-docker-a", "start"]