import asyncio
import os
import sys
from datetime import date, timedelta
import random

base_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(base_dir)

from app.db.session import SessionLocal
from app.models.student import Student
from app.models.attendance import Attendance, AttendanceStatus
from sqlalchemy import select

async def seed_attendance():
    async with SessionLocal() as db:
        # Get all students
        result = await db.execute(select(Student))
        students = result.scalars().all()
        
        if not students:
            print("No students found. Run seed_users.py first.")
            return

        today = date.today()
        first_day = today.replace(day=1)
        
        # Calculate days to seed
        days_diff = (today - first_day).days + 1
        
        print(f"Seeding attendance for {len(students)} students from {first_day} to {today}")

        for student in students:
            # Check if attendance already exists for this student for this month
            stmt = select(Attendance).where(
                Attendance.student_id == student.id,
                Attendance.attendance_date >= first_day
            )
            existing_result = await db.execute(stmt)
            if existing_result.scalars().first():
                print(f"Attendance already seeded for student ID {student.id}. Skipping.")
                continue

            for i in range(days_diff):
                current_date = first_day + timedelta(days=i)
                
                # Skip weekends
                if current_date.weekday() >= 5: # 5=Saturday, 6=Sunday
                    continue
                
                # Random status logic for realistic data
                # 85% Present, 5% Late, 5% Absent, 5% Early Leave
                rand = random.randint(1, 100)
                if rand <= 85:
                    status = AttendanceStatus.PRESENT
                elif rand <= 90:
                    status = AttendanceStatus.LATE
                elif rand <= 95:
                    status = AttendanceStatus.ABSENT
                else:
                    status = AttendanceStatus.EARLY_LEAVE
                    
                attendance = Attendance(
                    student_id=student.id,
                    attendance_date=current_date,
                    status=status
                )
                db.add(attendance)
            
            await db.commit()
            print(f"Seeded attendance for student ID {student.id}")
        
        print("Attendance seeding completed.")

if __name__ == "__main__":
    asyncio.run(seed_attendance())
