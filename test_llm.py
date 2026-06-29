import asyncio
from backend.app.core.llm import get_llm

async def main():
    print("Testing LLM instantiation and keep_alive parameter...")
    try:
        llm = get_llm()
        print(f"Model configured: {llm.model}")
        print("Invoking model (this might take a few seconds if loading)...")
        # 단답형을 요구하여 빠른 처리 시도
        res = await llm.ainvoke("Say 'Hello' and nothing else.")
        print("Response:", res.content)
        print("Check task manager/Ollama to verify VRAM unloaded.")
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    asyncio.run(main())
