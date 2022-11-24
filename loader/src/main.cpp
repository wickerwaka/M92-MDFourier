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
    pinMode(pin, OUTPUT);
  } else {
    digitalWrite(pin, LOW);
    pinMode(pin, OUTPUT);
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

static constexpr uint8_t PREAMBLE[] = {
  0x00, 0x99, 0x11, 0x22,
  0x33, 0x44, 0x55, 0x66,
  0x77, 0x88, 0xFF, 0xAA,
  0xBB, 0xCC, 0xDD, 0xFF
};

uint8_t cmd_buffer[2048];

void loop() {
  if( Serial.find(PREAMBLE, sizeof(PREAMBLE)) ) {
    uint16_t length;
    if( Serial.readBytes((uint8_t *)&length, sizeof(length)) != sizeof(length) ) {
      return;
    }

    if( Serial.readBytes(cmd_buffer, length) == length ) {
      send_block(cmd_buffer, length);
      char status[128];
      sprintf(status, "Sent %d bytes.", length);
      Serial.println(status);
    }
  }
}