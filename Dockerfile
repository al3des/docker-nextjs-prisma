# Stage 1: Install dependencies
FROM oven/bun AS base
WORKDIR /usr/src/app

# install dependencies into temp directory
# this will cache them and speed up future builds
FROM base AS install
#WORKDIR /app
RUN mkdir -p /temp/dev
COPY package.json bun.lock /temp/dev/
RUN cd /temp/dev && bun install --frozen-lockfile

# install with --production (exlude devDependencies)
RUN mkdir -p /temp/prod
COPY package.json bun.lock /temp/prod/
RUN cd /temp/prod && bun install --frozen-lockfile --production

# copy node_modules from temp directory
# then copy all (non-ignored_ project files into the image
FROM base AS prerelease
COPY --from=install /temp/dev/node_modules node_modules
COPY . .
# Stage 2: Build the application
# WORKDIR /app
# COPY --from=deps /app/node_modules ./node_modules
# COPY . .
# [optional] test & build
ENV NODE_ENV=production
RUN bun test
RUN bun run build

# copy production dependencies and source code into final image
FROM base AS release
COPY --from=install /temp/prod/node_modules node_modules
# COPY --from=prerelease /usr/src/app/index.ts .
COPY --from=prerelease /usr/src/app/package.json .

# Copy necessary files from the builder stage
COPY --from=prerelease /usr/src/app/public ./public
COPY --from=prerelease /usr/src/app/.next/standalone ./
COPY --from=prerelease /usr/src/app/.next/static ./.next/static

# Include the Prisma directory
COPY --from=prerelease /usr/src/app/prisma ./prisma


# USER bun
# Expose the application port
EXPOSE 3000/tcp

# Run database deployment and start the server
#CMD ["sh", "-c", "bun run db:deploy && bun run server.js"]
RUN bun run db:deploy
ENTRYPOINT ["bun", "run", "server.js"]
