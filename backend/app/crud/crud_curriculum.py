from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import delete

from app.models.curriculum import CurriculumStep
from app.schemas.curriculum import CurriculumStepCreate, CurriculumStepUpdate

class CRUDCurriculumStep:
    async def get_multi(self, db: AsyncSession, skip: int = 0, limit: int = 100) -> List[CurriculumStep]:
        result = await db.execute(
            select(CurriculumStep)
            .order_by(CurriculumStep.display_order.asc(), CurriculumStep.id.asc())
            .offset(skip)
            .limit(limit)
        )
        return result.scalars().all()

    async def get(self, db: AsyncSession, id: int) -> Optional[CurriculumStep]:
        result = await db.execute(select(CurriculumStep).where(CurriculumStep.id == id))
        return result.scalar_one_or_none()

    async def create(self, db: AsyncSession, obj_in: CurriculumStepCreate) -> CurriculumStep:
        db_obj = CurriculumStep(**obj_in.dict())
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)
        return db_obj

    async def update(self, db: AsyncSession, db_obj: CurriculumStep, obj_in: CurriculumStepUpdate) -> CurriculumStep:
        update_data = obj_in.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)
        return db_obj

    async def remove(self, db: AsyncSession, id: int) -> Optional[CurriculumStep]:
        obj = await self.get(db=db, id=id)
        if obj:
            await db.execute(delete(CurriculumStep).where(CurriculumStep.id == id))
            await db.commit()
        return obj

curriculum_step = CRUDCurriculumStep()
