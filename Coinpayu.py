import time
import random
import os
from playwright.sync_api import sync_playwright

# --- CONFIGURAZIONE ---
USER_DATA = r"C:\Users\Admin\Desktop\Sessione_YouTube_NUOVA"
URL_ADS = "https://www.coinpayu.com/dashboard/ads_surf"

# Range coordinate (Modifica i valori Y se la lista è più in alto o in basso)
X_RANGE = (725, 850)
Y_RANGE = (400, 600)  # Area verticale dove compaiono gli annunci

WAIT_TIME = 46  # 45 secondi di timer + 1 di sicurezza

def avvia_grinder_totale():
    # Sblocco automatico della sessione per evitare il crash "apri e chiudi"
    lock_path = os.path.join(USER_DATA, "SingletonLock")
    if os.path.exists(lock_path):
        try:
            os.remove(lock_path)
            print("🔓 Sessione sbloccata.")
        except:
            pass

    with sync_playwright() as p:
        print(f"🚀 Modalità 'Full Random Area' attiva!")
        print(f"🎯 Mirino impostato su X:{X_RANGE} e Y:{Y_RANGE}")
        
        context = p.chromium.launch_persistent_context(
            USER_DATA,
            headless=False,
            channel="chrome",
            args=["--start-maximized"],
            no_viewport=True
        )
        
        page = context.pages[0]
        page.goto(URL_ADS, wait_until="networkidle")
        time.sleep(5)

        while True:
            try:
                # Generiamo coordinate casuali per X e Y
                rand_x = random.randint(X_RANGE[0], X_RANGE[1])
                rand_y = random.randint(Y_RANGE[0], Y_RANGE[1])
                
                print(f"🖱️ Clic randomico in corso... [X={rand_x}, Y={rand_y}]")
                
                # Aspettiamo l'apertura della nuova scheda (popup)
                with context.expect_page(timeout=12000) as popup_info:
                    page.mouse.click(rand_x, rand_y)
                
                ad_page = popup_info.value
                print(f"⏳ Annuncio intercettato. Attesa di {WAIT_TIME} secondi...")
                
                # Attesa obbligatoria per il credito dei Satoshi
                time.sleep(WAIT_TIME)
                
                # Chiudiamo solo la scheda pubblicitaria
                ad_page.close()
                print("✅ Lavoro sporco fatto. Torno alla lista.")
                
                # Pausa strategica e ricarica pagina per "pulire" la lista
                time.sleep(4)
                page.reload()
                time.sleep(5)

            except Exception:
                # Se il clic non apre nulla (area vuota o già cliccata)
                print("⚠️ Nulla è apparso. Ricarico e riprovo...")
                page.reload()
                time.sleep(6)

if __name__ == "__main__":
    avvia_grinder_totale()
