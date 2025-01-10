#include <mcp_can.h>
#include <SPI.h>
#define SOP '<'
#define EOP '>'
#define LENGTH 5

#include <SoftwareSerial.h>

SoftwareSerial mySerial(16, 17); // RX, TX

long unsigned int rxId;
unsigned char len = 0;
unsigned char rxBuf[8];

unsigned long previousMillis = 0;  // Variabile per memorizzare l'ultimo tempo in cui il messaggio è stato inviato
const long interval = 1000;        // Intervallo di tempo

#define CAN0_INT 4                             
MCP_CAN CAN0(5);                               

int Speed = 0;
int Rpm = 0;
int Gear = 0;

// Funzione per inviare un messaggio via UART e verificare se il messaggio è stato inviato con successo
bool sendUartMessage(const char* message) {
  int bytesSent = mySerial.print(message);
  return bytesSent == strlen(message);  // Ritorna true se il numero di byte inviati corrisponde alla lunghezza del messaggio
}

// Funzione per ricevere dati via UART
void receiveUartData() {
    if (mySerial.available() >= 6) {
        uint8_t data[6];
        mySerial.readBytes(data, 6);

        // Verifica che il primo e l'ultimo elemento siano SOP e EOP
        if (data[0] == SOP && data[5] == EOP) {
            // Stampa gli elementi tra SOP e EOP
            for (int i = 1; i < 5; i++) {
                Serial.print(data[i]);
              }
                
                Serial.print(" \n");
                byte sndStat = CAN0.sendMsgBuf(0x100, 0, 6, data); // invio il messaggio via CAN
          
                if(sndStat == CAN_OK){
                  Serial.println("Messagio CAN inviato alla macchina!");
                } else {
                  Serial.println("Errore invio messaggio CAN...");
                }
            }
            Serial.println();
        }
    }

void setup()
{
  Serial.begin(9600);
  mySerial.begin(9600);
  
  if(CAN0.begin(MCP_ANY, CAN_100KBPS, MCP_8MHZ) == CAN_OK)
    Serial.println("CAN Inizializzato");
  else
    Serial.println("Errore con CAN...");
  
  CAN0.setMode(MCP_NORMAL);                     
  pinMode(CAN0_INT, INPUT);                    
}

void loop()
{
  receiveUartData();
  unsigned long currentMillis = millis();
  const char* message = nullptr;
  if(!digitalRead(CAN0_INT))                   
  {
    CAN0.readMsgBuf(&rxId, &len, rxBuf);

    if(rxId == 0x351) Speed = int(rxBuf[1]);
    if(rxId == 0x359) Gear = int(rxBuf[7]);
    if(rxId == 0x35B) Rpm = int(rxBuf[1]);
    
    if (Gear == 96) {
      message = "Incidente";
    } 
    else if (Rpm > 0 && Speed == 0) {
      message = "Traffico";
    } 
    else if (Rpm == 0 && Speed == 0) {
      message = "SOS";
    } 
    else if (Rpm > 0 && Speed > 0) {
      message = "OK";
      
    }
    else {
      message = "Lavori";
    }

  }

  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;

    message = "Lavori"; //Messaggio temporaneo per testare l'invio del messaggio via UART

    if (message) {
      Serial.println(message);
      
      // Verifica se il messaggio è stato inviato con successo
      if (sendUartMessage(message)) {
        Serial.println("Messaggio inviato via UART con successo.");
      } else {
        Serial.println("Errore: invio del messaggio via UART fallito.");
      }
    }
  }
}
