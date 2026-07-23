# RetailMind AI

AI-powered retail analytics platform.

## Project Structure

```
retailmind-ai/
├── backend/        → RetailMind Backend (API & services)
├── frontend/       → RetailMind Frontend (Web app)
├── docker-compose.yml
├── .env.example
└── README.md
```

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Git

### Setup

1. Clone the repository with submodules:

   ```bash
   git clone --recurse-submodules https://github.com/mwendiaeng/retailmind-ai.git
   cd retailmind-ai
   ```

2. Create your environment file:

   ```bash
   cp .env.example .env
   ```

3. Start the services:

   ```bash
   docker compose up -d
   ```

### Services

| Service  | URL               | Description         |
|----------|-------------------|---------------------|
| Frontend | http://localhost:3000 | Web application  |
| Backend  | http://localhost:8000 | API server       |
| Database | localhost:5432       | PostgreSQL       |

## Development

Each submodule is an independent repository:

- **Backend**: [retailmind-backend](https://github.com/mwendiaeng/retailmind-backend)
- **Frontend**: [retailmind-frontend](https://github.com/mwendiaeng/retailmind-frontend)

### Updating Submodules

```bash
git submodule update --remote --merge
```

## License

MIT
