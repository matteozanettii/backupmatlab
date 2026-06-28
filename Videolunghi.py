import os
from moviepy.editor import VideoFileClip, concatenate_videoclips
from pydub import AudioSegment
from pydub.silence import detect_nonsilent

def rimuovi_silenzi(input_path, output_path, min_silence_len=700, silence_thresh=-40):
    print(f"\n[*] Inizio elaborazione di: {os.path.basename(input_path)}")

    video = VideoFileClip(input_path)
    audio_temp_path = f"temp_audio_{os.path.basename(input_path)}.wav"
    
    print("[*] Estrazione audio per l'analisi...")
    video.audio.write_audiofile(audio_temp_path, logger=None)

    audio = AudioSegment.from_wav(audio_temp_path)
    print("[*] Ricerca dei silenzi in corso...")
    
    nonsilent_ranges = detect_nonsilent(audio, min_silence_len=min_silence_len, silence_thresh=silence_thresh)

    clips = []
    for start_ms, end_ms in nonsilent_ranges:
        start_sec = start_ms / 1000.0
        end_sec = min((end_ms / 1000.0) + 0.1, video.duration) 
        clips.append(video.subclip(start_sec, end_sec))

    print(f"[*] Trovate {len(clips)} clip valide. Unione in corso...")
    final_video = concatenate_videoclips(clips)

    print(f"[*] Esportazione in: {output_path}")
    final_video.write_videofile(output_path, codec="libx264", audio_codec="aac")

    video.close()
    final_video.close()
    if os.path.exists(audio_temp_path):
        os.remove(audio_temp_path)
        
    print(f"[*] Completato: {os.path.basename(input_path)}")

# ==========================================
# ESECUZIONE DINAMICA SULLA CARTELLA
# ==========================================
if __name__ == "__main__":
    cartella_input = "input"
    cartella_output = "output"

    os.makedirs(cartella_input, exist_ok=True)
    os.makedirs(cartella_output, exist_ok=True)

    # Cerca tutti i file video comuni generati da OBS
    estensioni_valide = ('.mp4', '.mkv', '.mov')
    file_video = [f for f in os.listdir(cartella_input) if f.lower().endswith(estensioni_valide)]

    if not file_video:
        print(f"[!] Nessun video trovato. Butta i tuoi file di OBS nella cartella '{cartella_input}' e riavvia.")
    else:
        for nome_file in file_video:
            percorso_input = os.path.join(cartella_input, nome_file)
            percorso_output = os.path.join(cartella_output, f"editato_{nome_file}")

            # Salta il file se è già stato tagliato in passato
            if os.path.exists(percorso_output):
                print(f"\n[*] Il file {nome_file} è già stato editato. Passo al prossimo...")
                continue

            rimuovi_silenzi(percorso_input, percorso_output)
            
        print("\n[*] Tutti i video nella cartella input sono stati processati.")
