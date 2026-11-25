// Prevents an extra console window on Windows in release mode
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::time::Duration;

#[tauri::command]
async fn fetch_bcv_exchange_rate_page() -> Result<String, String> {
    let client = reqwest::Client::builder()
        .user_agent("POS Nativo Beta")
        .timeout(Duration::from_secs(15))
        .build()
        .map_err(|error| format!("No se pudo preparar la consulta al BCV: {error}"))?;

    let response = client
        .get("https://www.bcv.org.ve/estadisticas/tipo-cambio-de-referencia-smc")
        .send()
        .await
        .map_err(|error| format!("No se pudo conectar con el BCV: {error}"))?
        .error_for_status()
        .map_err(|error| format!("El BCV respondió con un error: {error}"))?;

    response
        .text()
        .await
        .map_err(|error| format!("No se pudo leer la respuesta del BCV: {error}"))
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![fetch_bcv_exchange_rate_page])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}