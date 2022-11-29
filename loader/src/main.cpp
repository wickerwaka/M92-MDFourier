#include <Arduino.h>


constexpr uint8_t pins[] = { 2, 3, 4, 5, 10, 9, 8, 7 };

#define STROBE 10
#define B0 2
#define B1 3
#define B2 4
#define B3 5
#define BLK_START 9
#define BLK_END 8


#define STROBE_DELAY delayMicroseconds(200)
#define BLOCK_DELAY delay(50)


void send_bit(int pin, bool v) {
  if( v ) {
    digitalWrite(pin, HIGH);
  } else {
    digitalWrite(pin, LOW);
  }
}

void send_byte(uint8_t v) {
  send_bit(B0, v & (1 << 0));
  send_bit(B1, v & (1 << 1));
  send_bit(B2, v & (1 << 2));
  send_bit(B3, v & (1 << 3));
  send_bit(STROBE, false);
  STROBE_DELAY;

  send_bit(B0, false);
  send_bit(B1, false);
  send_bit(B2, false);
  send_bit(B3, false);
  send_bit(STROBE, true);
  STROBE_DELAY;

  send_bit(B0, v & (1 << 4));
  send_bit(B1, v & (1 << 5));
  send_bit(B2, v & (1 << 6));
  send_bit(B3, v & (1 << 7));
  send_bit(STROBE, false);
  STROBE_DELAY;

  send_bit(B0, false);
  send_bit(B1, false);
  send_bit(B2, false);
  send_bit(B3, false);
  send_bit(STROBE, true);
  STROBE_DELAY;  
}

void send_block(const void *ptr, int len) {
  send_bit(BLK_START, false);
  BLOCK_DELAY;
  send_bit(BLK_START, true);

  const uint8_t *data = (const uint8_t *)ptr;
  for( int i = 0; i < len; i++ ) {
    send_byte(data[i]);
  }

  send_bit(BLK_END, false);
  BLOCK_DELAY;
  send_bit(BLK_END, true);
}


void setup() {
  pinMode(B0, OUTPUT);
  pinMode(B1, OUTPUT);
  pinMode(B2, OUTPUT);
  pinMode(B3, OUTPUT);

  pinMode(STROBE, OUTPUT);
  pinMode(BLK_END, OUTPUT);
  pinMode(BLK_START, OUTPUT);

  send_bit(B0, false);
  send_bit(B1, false);
  send_bit(B2, false);
  send_bit(B3, false);

  send_bit(BLK_END, true);
  send_bit(BLK_START, true);
  send_bit(STROBE, true);


  Serial.begin(9600);
  Serial.setTimeout(5000);
}

static constexpr uint8_t MAGIC[] = { 0xfa, 0x23, 0x68, 0xaf };

uint8_t cmd_buffer[4096];

void loop() {
  int res;
  uint8_t pkt[48];
  if( Serial.find(MAGIC, sizeof(MAGIC))) {
    uint8_t seq, sz;
    res = Serial.readBytes(&seq, 1);
    if (res != 1) { Serial.println("0 BADSEQ"); return; };
    res = Serial.readBytes(&sz, 1);
    if (res != 1 || sz > 48 || sz < 2) { Serial.print(seq); Serial.println(" BADSZ"); return; };

    res = Serial.readBytes((uint8_t *)&pkt, sz);
    if (res != sz) { Serial.print(seq); Serial.println(" SHORT"); return; }

    uint16_t ofs = *(uint16_t *)&pkt[0];
    if (ofs == 0xffff) {
      uint16_t len = *(uint16_t *)&pkt[2];
      send_block(cmd_buffer, len);
      Serial.print(seq);
      Serial.println(" SENT");
    } else if( ofs < sizeof(cmd_buffer)) {
      if (ofs + sz > sizeof(cmd_buffer)) {
        Serial.print(seq);
        Serial.println(" TOOSZ");
      } else {
        memcpy(cmd_buffer + ofs, pkt + 2, sz - 2);
        Serial.print(seq);
        Serial.println(" ACK");
      }
    } else {
      Serial.print(seq);
      Serial.println(" NAK");
    }
  }
}