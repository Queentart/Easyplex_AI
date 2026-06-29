import os
import io

def parse_file_for_llm(file_path: str, file_type: str = None) -> str:
    """
    다양한 타입의 파일을 파싱하여 LLM이 이해할 수 있는 텍스트로 반환합니다.
    """
    if not os.path.exists(file_path):
        return "[Error: Attached file not found on server]"
        
    ext = os.path.splitext(file_path)[1].lower()
    
    # 1. 텍스트 및 코드 파일
    text_extensions = {'.txt', '.md', '.csv', '.json', '.py', '.js', '.ts', '.html', '.css', '.java', '.cpp', '.c'}
    if ext in text_extensions or (file_type and file_type.startswith('text/')):
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                max_len = 15000
                if len(content) > max_len:
                    content = content[:max_len] + f"\n... [Content truncated, total length: {len(content)}]"
                return f"[Text/Code File Content]\n{content}"
        except Exception as e:
            # utf-8 실패시
            return f"[Error parsing text file (possibly binary/encoded): {str(e)}]"
            
    # 2. PDF 문서
    if ext == '.pdf' or (file_type and file_type == 'application/pdf'):
        try:
            from pypdf import PdfReader
            reader = PdfReader(file_path)
            text = ""
            for i, page in enumerate(reader.pages):
                if i >= 10: # 처음 10페이지만 분석 (LLM 한계 보호)
                    text += "\n... [Remaining pages omitted]"
                    break
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
            return f"[PDF Document Content]\n{text}"
        except Exception as e:
            return f"[Error parsing PDF: {str(e)}]"
            
    # 3. 오디오 파일
    audio_extensions = {'.wav', '.mp3', '.ogg', '.m4a', '.flac'}
    if ext in audio_extensions or (file_type and file_type.startswith('audio/')):
        try:
            import speech_recognition as sr
            from pydub import AudioSegment
            
            audio = AudioSegment.from_file(file_path)
            wav_path = file_path + "_temp.wav"
            
            # 처음 1분만 변환 (처리 시간 절약)
            if len(audio) > 60000:
                audio = audio[:60000]
                
            audio.export(wav_path, format="wav")
            
            r = sr.Recognizer()
            with sr.AudioFile(wav_path) as source:
                audio_data = r.record(source)
                
            os.remove(wav_path)
            
            # 구글 Web Speech API 활용
            text = r.recognize_google(audio_data, language="ko-KR")
            return f"[Audio Transcript (First 1 min)]\n{text}"
        except Exception as e:
            return f"[Audio File Metadata]\n- Extension: {ext}\n- Error extracting speech: {str(e)}\n(Manual grading is recommended)"
            
    # 4. 이미지 및 비디오 파일
    image_extensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'}
    video_extensions = {'.mp4', '.avi', '.mov', '.mkv'}
    
    if ext in image_extensions or (file_type and file_type.startswith('image/')):
        try:
            from PIL import Image
            with Image.open(file_path) as img:
                width, height = img.size
                format = img.format
                mode = img.mode
            return f"[Image File Metadata]\n- Format: {format}\n- Resolution: {width}x{height}\n- Mode: {mode}\n(Note: Visual content is not directly processed by text-only LLM. Manual review recommended.)"
        except Exception as e:
            return f"[Error reading image metadata: {str(e)}]"
            
    if ext in video_extensions or (file_type and file_type.startswith('video/')):
        file_size_mb = os.path.getsize(file_path) / (1024 * 1024)
        return f"[Video File]\n- Extension: {ext}\n- Size: {file_size_mb:.2f} MB\n(Note: Video processing requires manual review by the instructor.)"

    # 기타 미지원
    file_size_mb = os.path.getsize(file_path) / (1024 * 1024)
    return f"[Unsupported File Type]\n- Extension: {ext}\n- Size: {file_size_mb:.2f} MB\n(Note: The AI cannot read this file type. Manual grading required.)"
