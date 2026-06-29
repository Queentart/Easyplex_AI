# Full Stack Dockerization Plan

This plan details the steps to properly Dockerize both your FastAPI backend and React frontend, ensuring they can communicate seamlessly along with the pgvector DB and Redis cache.

## User Review Required
- **Backend Dockerfile Changes**: I will fix your root `Dockerfile`. Currently, it copies the `backend` folder to `/app/backend`, but the FastAPI app expects to run from the folder containing `app/main.py`. I will adjust the `WORKDIR` and CMD to `"uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"`.
- **Frontend Dockerfile**: I will create a new `frontend/Dockerfile` that uses a multi-stage build. It will build the Vite app using Node and serve the static files using a lightweight Nginx web server on port 80.
- **docker-compose.yml fixes**:
  - `pgvector/pgvector:pg18` does not exist yet (latest is pg17). I will revert it to `pg17` to prevent image pull errors.
  - I will add environment variables to the `backend` service (`POSTGRES_SERVER=db`, `REDIS_HOST=redis`) so it knows to connect to the Docker containers instead of `localhost`.
  - I will add the `frontend` service to `docker-compose.yml`.

## Open Questions
- Do you want the frontend to run as a **development server** (hot-reloading enabled, `npm run dev`) inside Docker, or as a **production build** (Nginx serving `dist/` folder)? I will default to **production build (Nginx)** as it's the standard way to deploy React apps in Docker, but let me know if you prefer dev mode.

## Proposed Changes

---

### Backend Docker Configuration

#### [MODIFY] [Dockerfile](file:///C:/Easyplex_AI/Dockerfile)
- Change `CMD` to `["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]`
- Add `WORKDIR /app/backend` before CMD so Python imports work correctly.

#### [MODIFY] [docker-compose.yml](file:///C:/Easyplex_AI/docker-compose.yml)
- Revert `db` image to `pgvector/pgvector:pg17`.
- Update `backend` environment variables:
  - `POSTGRES_SERVER: db`
  - `REDIS_HOST: redis`
- Update `backend` volume mapping to `- ./backend:/app/backend` to match the Dockerfile structure.

---

### Frontend Docker Configuration

#### [NEW] [frontend/Dockerfile](file:///C:/Easyplex_AI/frontend/Dockerfile)
Create a multi-stage Dockerfile:
1. `node:20-alpine` to `npm install` and `npm run build`.
2. `nginx:alpine` to copy the `dist` folder to `/usr/share/nginx/html` and expose port 80.

#### [MODIFY] [docker-compose.yml](file:///C:/Easyplex_AI/docker-compose.yml)
Add the `frontend` service:
```yaml
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: react_frontend
    ports:
      - "3000:80"
    depends_on:
      - backend
```

---

## Verification Plan
1. We will stop any running containers using `docker-compose down`.
2. We will run `docker-compose up -d --build` to build and start the entire stack (DB, Redis, Backend, Frontend).
3. We will check logs for any startup errors.
4. The frontend will be accessible at `http://localhost:3000` and the backend at `http://localhost:8000`. They will communicate via the user's browser without issue.
