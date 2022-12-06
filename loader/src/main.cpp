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

constexpr unsigned short MAN_TIMEOUT = 1000;
unsigned long man_prev_us = 0;
bool man_sync = true;
unsigned short man_clk_us = 0;
bool man_midpoint = false;

constexpr uint16_t MAN_BUFFER_SZ = 256;
uint8_t man_buffer[MAN_BUFFER_SZ];
uint16_t man_buffer_head = 0;
uint16_t man_buffer_tail = 0;
uint8_t man_bits = 0;
uint8_t man_bit_count = 0;

void man_bit(bool b) {
  man_bits = ( man_bits << 1 ) | ( b ? 1 : 0);
  man_bit_count++;
  if (man_bit_count == 8) {
    man_bit_count = 0;
    if (man_buffer_head - man_buffer_tail < MAN_BUFFER_SZ) {
      man_buffer[man_buffer_head % MAN_BUFFER_SZ] = man_bits;
      man_buffer_head++;
    }
    man_bits = 0;
  }
}

int man_read() {
  if( man_buffer_tail == man_buffer_head ) {
    return -1;
  }

  int ret = man_buffer[man_buffer_tail % MAN_BUFFER_SZ];
  man_buffer_tail++;

  return ret;
}

unsigned short diffs[256];
uint8_t diff_idx = 0;

void manchester_isr()
{
  unsigned long us = micros();
  unsigned short diff = us - man_prev_us;
  man_prev_us = us;

  diffs[diff_idx] = diff;
  diff_idx++;

  if ( diff > MAN_TIMEOUT ) {
    man_sync = true;
    man_bits = 0;
    man_bit_count = 0;
  } else {
    if (man_sync) {
      man_clk_us = diff;
      man_midpoint = true;
      man_sync = false;
    } else {
      unsigned short half_clk = man_clk_us >> 1;
      unsigned short high = man_clk_us + half_clk;
      if (diff < high) { // short pulse
        if (man_midpoint) { // end transition
          man_midpoint = false;
          man_bit(true);
        } else {
          man_midpoint = true;
        }
        man_clk_us = ( man_clk_us + diff ) >> 1;
      } else {
        man_bit(false);
        man_clk_us = ( man_clk_us + man_clk_us + diff ) >> 2;
      }
    }
  }
}

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


  pinMode(21, INPUT);
  attachInterrupt(digitalPinToInterrupt(21), manchester_isr, CHANGE);

  Serial.begin(115200);
  Serial.setTimeout(1000);
}

static constexpr uint8_t MAGIC[] = { 0xfa, 0x23, 0x68, 0xaf };

uint8_t cmd_buffer[4096];

void loop() {
  int res;
/*
  Serial.print("DEBUG: us: ");

  for( int i = 0; i < 64; i++ )
  {
    Serial.print(diffs[i]);
    Serial.print(" ");
  }
  Serial.println();

  Serial.print("DEBUG: BUF: ");

  while( true )
  {
    res = man_read();
    if( res == -1 ) break;
    Serial.print(res);
    Serial.print(" ");
  }
  Serial.println();
*/

  /*while( true )
  {
    res = man_read();
    if( res == -1 ) break;
    Serial.print((char)res);
  }*/

  uint8_t pkt[48];
  if( Serial.available() > sizeof(MAGIC) && Serial.find(MAGIC, sizeof(MAGIC))) {
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
      uint16_t resp_len = *(uint16_t *)&pkt[4];

      // flush receive buffer
      if (resp_len) {
        while( man_read() != -1 ) {};
      }

      send_block(cmd_buffer, len);
      Serial.print(seq);
      Serial.println(" SENT");

      unsigned long start_ms = millis();
      uint16_t bytes_read = 0;
      while( ( millis() < (start_ms + 1000) ) && bytes_read < resp_len ) {
        int resp = man_read();
        if( resp != -1 ) {
          Serial.write((uint8_t)resp);
          bytes_read++;
        }
      }
      /*if (resp_len) {
        Serial.print("DEBUG: us: ");

        for( int i = 0; i < 64; i++ )
        {
          Serial.print(diffs[i]);
          Serial.print(" ");
        }
        Serial.println();
        Serial.print(seq);
        Serial.println(" RESP");
      }*/
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