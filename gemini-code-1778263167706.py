import os
import sys
import subprocess
import shutil
import datetime

# ==========================================
# 1. CONTROLLO E INSTALLAZIONE DIPENDENZE
# ==========================================
def setup_ambiente():
    print("🔧 Controllo l'ambiente di lavoro...")
    
    # 1A. Controllo FFmpeg (Deve essere installato nel sistema operativo)
    if not shutil.which("ffmpeg"):
        print("\n❌ ERRORE: FFmpeg non è installato nel sistema!")
        print("FFmpeg è un programma essenziale per modificare i video.")
        print("👉 ISTRUZIONI: Scaricalo da https://ffmpeg.org/download.html, installalo")
        print("e assicurati che sia aggiunto alle variabili di ambiente del tuo sistema.")
        input("\nPremi Invio per chiudere...")
        sys.exit(1)

    # 1B. Controllo e installazione pacchetti Python
    # Whisper (per la trascrizione)
    try:
        import whisper
    except ImportError:
        print("📦 'whisper' non trovato. Installazione in corso (potrebbe volerci un po')...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "openai-whisper"])
        print("✅ whisper installato!")

    # Auto-editor (per il taglio dei silenzi)
    if not shutil.which("auto-editor"):
        print("📦 'auto-editor' non trovato. Installazione in corso...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "auto-editor"])
        print("✅ auto-editor installato!")
        
    print("✅ Ambiente di lavoro pronto!\n")

# Avviamo il setup prima di importare whisper globalmente
setup_ambiente()

import whisper  # Ora siamo sicuri che esista

# ==========================================
# 2. FUNZIONI DI SUPPORTO
# ==========================================
def format_timestamp(seconds):
    """Converte i secondi nel formato corretto per i sottotitoli SRT"""
    td = datetime.timedelta(seconds=seconds)
    total_seconds = int(td.total_seconds())
    hours = total_seconds // 3600
    minutes = (total_seconds % 3600) // 60
    secs = total_seconds % 60
    millis = int(td.microseconds / 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"

def generate_srt(video_path):
    """Usa l'IA per ascoltare il video e creare i sottotitoli"""
    print("🎙️ 1. Generazione testi con Whisper (Modello Base)...")
    # Puoi cambiare "base" in "small" o "medium" se vuoi più precisione (ma sarà più lento)
    model = whisper.load_model("base") 
    result = model.transcribe(video_path, language="Italian")
    
    srt_name = "subs.srt"
    with open(srt_name, "w", encoding="utf-8") as srt:
        for i, segment in enumerate(result['segments']):
            start = format_timestamp(segment['start'])
            end = format_timestamp(segment['end'])
            # Testo in maiuscolo per leggibilità immediata
            text = segment['text'].strip().upper()
            srt.write(f"{i+1}\n{start} --> {end}\n{text}\n\n")
    return srt_name

# ==========================================
# 3. MOTORE PRINCIPALE
# ==========================================
def avvia_produzione():
    print("--- ⚡ ZANNA WHITE: SHORTS MINIMALI ---")
    
    video_input = input("🎬 Trascina il file video qui e premi Invio: ").strip().replace('"', '').replace("'", "")
    
    if not os.path.exists(video_input):
        print("❌ Errore: File video non trovato. Assicurati di averlo trascinato correttamente.")
        return

    original_dir = os.getcwd()
    video_dir = os.path.dirname(os.path.abspath(video_input))
    os.chdir(video_dir)
    
    video_filename = os.path.basename(video_input)
    temp_cut = "temp_cut.mp4"
    srt_file = "subs.srt"
    output_final = f"MINIMAL_{video_filename}"

    try:
        # 1. TAGLIO SILENZI
        print("\n⏳ 1/3 - Taglio automatico dei silenzi...")
        subprocess.run(["auto-editor", video_filename, "--margin", "0.1s", "-o", temp_cut], check=True)

        # 2. SOTTOTITOLI
        print("\n⏳ 2/3 - Creazione sottotitoli in corso...")
        generate_srt(temp_cut)

        # 3. BURNING MINIMALE
        print("\n⏳ 3/3 - Applicazione stile minimalista sul video...")
        
        style = (
            "FontName=Arial Black," 
            "Alignment=2,"              # Centro-Basso
            "MarginV=120,"              # Posizione abbassata
            "FontSize=10,"              # Dimensione ridotta
            "PrimaryColour=&H00FFBF00," # Colore giallo/azzurro chiaro (modificabile)
            "OutlineColour=&H000000,"   # Bordo nero sottile
            "BorderStyle=1,"            # Semplice testo con bordo
            "Outline=1.5,"              # Spessore del bordo
            "Shadow=0"                  # Niente ombra
        )
        
        comando_ffmpeg = [
            "ffmpeg", "-y", "-i", temp_cut, 
            "-vf", f"subtitles={srt_file}:force_style='{style}'",
            "-c:a", "copy", output_final
        ]
        
        # Uso 'DEVNULL' per non inondare lo schermo con il testo di FFmpeg
        subprocess.run(comando_ffmpeg, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)

        print(f"\n✅ LAVORO COMPLETATO! Il video è pronto: {output_final}")

    except subprocess.CalledProcessError as e:
        print(f"\n❌ Si è verificato un errore durante l'elaborazione di un comando esterno (es. auto-editor o ffmpeg).")
    except Exception as e:
        print(f"\n❌ Errore imprevisto: {e}")
    finally:
        # Pulizia dei file temporanei
        print("\n🧹 Pulizia file temporanei...")
        os.chdir(original_dir)
        if os.path.exists(os.path.join(video_dir, temp_cut)): 
            os.remove(os.path.join(video_dir, temp_cut))
        if os.path.exists(os.path.join(video_dir, srt_file)): 
            os.remove(os.path.join(video_dir, srt_file))

if __name__ == "__main__":
    avvia_produzione()
    input("\nPremi Invio per chiudere il programma...")