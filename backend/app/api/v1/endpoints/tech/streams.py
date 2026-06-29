from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional

router = APIRouter()

class StreamCreate(BaseModel):
    title: str
    url: str
    platform: str

@router.get("/")
async def get_streams():
    return {
        "status": "success",
        "data": [
            { "id": "1", "title": "Week 1: Introduction to React", "date": "2026-06-01", "platform": "YouTube", "url": "https://youtube.com/watch?v=mock1", "status": "Archived", "thumbnail": "/thumbnails/react_thumbnail.png" },
            { "id": "2", "title": "Week 2: Advanced State Management", "date": "2026-06-08", "platform": "Vimeo", "url": "https://vimeo.com/mock2", "status": "Archived", "thumbnail": "/thumbnails/state_thumbnail.png" },
            { "id": "3", "title": "Week 3: Backend Integration (Live)", "date": "2026-06-16", "platform": "YouTube", "url": "https://youtube.com/watch?v=mock3", "status": "Live", "thumbnail": null },
        ]
    }

@router.post("/")
async def create_stream(stream: StreamCreate):
    return {"message": "Stream created placeholder", "data": stream}
