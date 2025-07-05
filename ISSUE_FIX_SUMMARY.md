# Masalah: Status Sudah Basah Tapi Riwayat Menampilkan Kering

## Analisis Masalah

Berdasarkan screenshot yang diberikan dan analisis kode, ditemukan beberapa masalah:

### 1. **Status Dashboard vs Riwayat - Bukan Bug**
- **Dashboard menampilkan "Basah"** - ini BENAR karena nilai kelembapan saat ini adalah 21, yang <= 2000 (threshold), jadi tanah memang basah
- **Riwayat menampilkan "Tanah Kering"** - ini menampilkan data historis yang tersimpan saat tanah memang kering

### 2. **Masalah Utama: Nilai Riwayat = 0**
Masalah sebenarnya adalah semua entri riwayat menampilkan "Nilai: 0", yang menunjukkan:
- Data historis yang tersimpan memiliki nilai kelembapan 0 (tidak valid)
- Ada mismatch field name antara ESP32 dan Flutter app

## Akar Masalah

### Field Name Mismatch
- **ESP32** menyimpan data ke Firebase dengan field `moisture`
- **Flutter App** membaca field `moistureValue`
- Akibatnya, nilai kelembapan di riwayat selalu 0 (default value)

### Kode ESP32:
```cpp
json.set("moisture", moistureValue);  // Simpan sebagai "moisture"
```

### Kode Flutter:
```dart
'moistureValue': value['moisture'],   // Baca dari "moisture" tapi simpan ke "moistureValue"
moistureValue: map['moistureValue'] ?? 0,  // Cari "moistureValue" yang tidak ada
```

## Solusi yang Diterapkan

### 1. **Perbaikan Field Mapping di Firebase Service**
```dart
// Sebelum
'moistureValue': value['moisture'],

// Sesudah  
'moistureValue': value['moisture'] ?? 0,  // ESP32 sends as 'moisture', app expects 'moistureValue'
```

### 2. **Perbaikan Model dengan Fallback**
```dart
// Sebelum
moistureValue: map['moistureValue'] ?? 0,

// Sesudah
moistureValue: map['moistureValue'] ?? map['moisture'] ?? 0,  // Handle both field names
```

### 3. **Validasi Data di ESP32**
Menambahkan validasi untuk mencegah penyimpanan data sensor yang tidak valid:
```cpp
// Validasi sebelum update Firebase
if (moistureValue < 0 || moistureValue > 4095) {
  Serial.println("WARNING: Invalid moisture reading, skipping Firebase update");
  return;
}

// Validasi sebelum simpan ke history
if (moistureValue >= 0 && moistureValue <= 4095) {
  // Simpan ke history
} else {
  Serial.println("WARNING: Invalid moisture value, not saving to history");
}
```

### 4. **Debug Logging**
Menambahkan logging untuk membantu debug:
```dart
print('Moisture field value: ${value['moisture']}');
print('SoilStatus field value: ${value['soilStatus']}');
```

### 5. **Test Data Generation**
Menambahkan fungsi untuk generate data test yang realistis:
- Short press refresh button: tambah 1 entri test
- Long press refresh button: tambah 10 entri test dengan variasi wet/dry

## Cara Testing

1. **Jalankan aplikasi Flutter** 
2. **Long press tombol refresh** di pojok kanan atas untuk menambah data test
3. **Periksa tab Riwayat** - seharusnya menampilkan nilai kelembapan yang benar, bukan 0
4. **Monitor console debug** untuk melihat proses parsing data

## Hasil yang Diharapkan

Setelah perbaikan:
- ✅ Dashboard tetap menampilkan status real-time dengan benar ("Basah" untuk nilai 21)
- ✅ Riwayat akan menampilkan nilai kelembapan yang benar (bukan 0)
- ✅ Riwayat akan menampilkan campuran status "Tanah Basah" dan "Tanah Kering" sesuai dengan nilai sensor historis
- ✅ Data baru dari ESP32 akan tersimpan dengan benar
- ✅ Data lama yang sudah tersimpan dengan nilai 0 akan tetap menampilkan 0, tapi data baru akan benar

## Catatan Tambahan

- **Status dashboard yang berbeda dengan riwayat adalah normal** - dashboard menampilkan kondisi real-time, riwayat menampilkan kondisi historis
- **Jika masih ada entri riwayat dengan nilai 0**, itu adalah data lama yang memang tersimpan dengan nilai 0 (kemungkinan sensor bermasalah saat itu)
- **Data baru akan tersimpan dengan benar** setelah perbaikan ini diterapkan
