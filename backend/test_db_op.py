import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select
from app.models.instructor_models import InstructorTicket
import re

async def main():
    engine = create_async_engine("postgresql+asyncpg://postgres:1234@localhost:5432/easyplex_db", echo=True)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as db:
        try:
            student_name = "Test Student"
            message = "[test] Hello"
            category_match = re.match(r"^\[(.*?)\]", message)
            
            result = await db.execute(select(InstructorTicket).where(InstructorTicket.student_name == student_name).order_by(InstructorTicket.created_at.desc()))
            ticket = result.scalars().first()
            
            if not ticket or ticket.status != "pending" or category_match:
                new_ticket = InstructorTicket(
                    student_name=student_name,
                    message=message,
                    status="pending"
                )
                db.add(new_ticket)
                await db.commit()
                await db.refresh(new_ticket)
                print("Created ticket", new_ticket.id)
            else:
                ticket.message += f"\n\n[추가 문의]\n{message}"
                db.add(ticket)
                await db.commit()
                print("Appended to ticket", ticket.id)
                
        except Exception as e:
            print("ERROR:", str(e))
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
