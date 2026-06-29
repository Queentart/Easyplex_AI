# AI Help Bot FAQ UI & PostgreSQL Seed Implementation Plan

This document outlines the changes to implement the KakaoTalk-style FAQ UI for the AI Help Bot and to seed PostgreSQL with dummy FAQ data (including placeholder vector data for future RAG usage).

## Proposed Changes

### Backend Database (PostgreSQL)
We will introduce a new SQLAlchemy model to store FAQ data, including a JSON or Array column for vector embeddings to support future RAG implementations.

#### [NEW] [faq.py](file:///c:/Easyplex_AI/backend/app/models/faq.py)
- Create `FAQItem` model inheriting from SQLAlchemy's `Base`.
- Fields: `id`, `category`, `question`, `answer`, `embedding` (to store vector data, defaulting to `ARRAY(Float)` or `JSON`).

#### [MODIFY] [support.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/student/support.py)
- Add `GET /api/v1/student/support/faqs`: Fetch FAQ list for the frontend.
- Add `POST /api/v1/student/support/seed-faqs`: A utility endpoint to seed dummy FAQ data with placeholder embeddings into the PostgreSQL database.

### Frontend UI (AIHelpBot)
We will introduce a swipeable/draggable horizontal bar (or expander) right above the chat input field, visible only in the `faq` channel.

#### [MODIFY] [AIHelpBot.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/AIHelpBot.tsx)
- Add an API call to fetch FAQs from the backend on component mount.
- UI Update: Above the `chat-input-wrapper`, render a horizontal scrolling list of FAQ chips (e.g., "외출 몇 시간까지 가능한가요?").
- When a user clicks a chip, it automatically populates the input field and/or sends the message to the AI bot immediately.
- The UI will be designed like a neat drawer or sliding banner above the text input.

## User Review Required
> [!IMPORTANT]
> The `pgvector` extension might not be enabled in your local PostgreSQL instance by default. For now, I will use SQLAlchemy's built-in `ARRAY(Float)` or `JSON` type to store the vector embeddings as placeholders. This ensures the RAG structure is ready without breaking your current DB setup. When you implement the actual RAG pipeline, you can migrate this column to `pgvector`'s `Vector` type. Do you approve of this approach?
