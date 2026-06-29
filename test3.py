import asyncio  
import asyncpg  
async def main():  
    sys_conn = await asyncpg.connect('postgresql://postgres:1234@localhost:5432/postgres')  
    await sys_conn.execute('CREATE DATABASE easyplex_db')  
    await sys_conn.close()  
    print('DB CREATED')  
asyncio.run(main())  
