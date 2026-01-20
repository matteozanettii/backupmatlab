import tweepy
import schedule
import time
import datetime
import os

# --- LE TUE CHIAVI ESATTE ---
# Consumer Keys (Dell'App)
API_KEY = "OsH6rC9pi7SWMYg9TsS3Vmrzk"
API_SECRET = "2NDcEd9PWIMtVi0WAouFM5REhL8UV9Ayvm0YkfgxqTRv56AS6o"

# Access Tokens (Del tuo account @Mondoapkit)
ACCESS_TOKEN = "1886507639334645760-RmNv5noPc2RhacWXEN8BvrYJXwJOqm"
ACCESS_SECRET = "B0ElviVLVPJk1iXu4EGk4ujCkMbbkuoeoJpLasRSouDy3"

FILE_CALENDARIO = "calendario_x.txt"

def invia_tweet(testo):
    print(f"🚀 Tentativo invio tweet...")
    try:
        # Autenticazione API v2
        client = tweepy.Client(
            consumer_key=API_KEY,
            consumer_secret=API_SECRET,
            access_token=ACCESS_TOKEN,
            access_token_secret=ACCESS_SECRET
        )
        
        response = client.create_tweet(text=testo)
        print(f"✅ TWEET INVIATO CON SUCCESSO! ID: {response.data['id']}")
        return True
    except Exception as e:
        print(f"❌ ERRORE X: {e}")
        if "403" in str(e):
            print("⚠️ ATTENZIONE: Errore 403 significa che i permessi 'Read and Write' non erano attivi quando hai generato le chiavi.")
            print("Soluzione: Vai su Settings -> User Authentication -> Seleziona Read and Write -> Poi RIGENERA le chiavi.")
        return False

def controlla_e_posta():
    if not os.path.exists(FILE_CALENDARIO):
        print("⚠️ File 'calendario_x.txt' non trovato!")
        print("💡 Usa lo script 'generatore_date.py' per crearlo automaticamente.")
        return

    # Leggi il calendario
    with open(FILE_CALENDARIO, "r", encoding="utf-8") as f:
        righe = f.readlines()

    righe_rimaste = []
    post_inviato_oggi = False
    ora_adesso = datetime.datetime.now()

    for riga in righe:
        riga = riga.strip()
        # Salta righe vuote o commenti
        if not riga or "|" not in riga: continue

        # Divide Data e Messaggio
        data_str, messaggio = riga.split("|", 1)
        messaggio = messaggio.strip()
        
        try:
            # Converte la data scritta nel file in un oggetto data vero
            data_prog = datetime.datetime.strptime(data_str.strip(), "%d/%m/%Y %H:%M")
            
            # SE la data/ora è passata (o è adesso) E non abbiamo ancora inviato oggi
            if ora_adesso >= data_prog and not post_inviato_oggi:
                succ = invia_tweet(messaggio)
                if succ:
                    post_inviato_oggi = True
                    # Il post è stato inviato, quindi NON lo salviamo in righe_rimaste (così si cancella)
                    print(f"🗑️ Rimosso dalla lista: {messaggio[:20]}...")
                else:
                    # Se c'è stato un errore, lo teniamo per riprovare
                    righe_rimaste.append(riga)
            else:
                # Se è un post futuro, lo teniamo
                righe_rimaste.append(riga)
                
        except ValueError:
            print(f"❌ Errore formato data: {data_str}")
            righe_rimaste.append(riga)

    # Riscriviamo il file pulito (senza il post appena inviato)
    if post_inviato_oggi:
        with open(FILE_CALENDARIO, "w", encoding="utf-8") as f:
            for r in righe_rimaste:
                f.write(r + "\n")

# --- AVVIO DEL MOTORE ---
print("🐦 BOT X (@Mondoapkit) ATTIVO!")
print("🕒 Controllo il calendario ogni 60 secondi.")
print("------------------------------------------------")

# Primo controllo immediato all'avvio
controlla_e_posta()

# Poi programma il controllo ogni minuto
schedule.every(60).seconds.do(controlla_e_posta)

while True:
    schedule.run_pending()
    time.sleep(1)
