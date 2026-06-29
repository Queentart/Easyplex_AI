import asyncio  
import asyncpg  
async def main():  
    conn = await asyncpg.connect('postgresql://postgres:1234@localhost:5432/postgres')  
    print('postgres DB CONNECTED')  
    await conn.close()  
asyncio.run(main())  
