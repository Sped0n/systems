---
urls:
  - https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/error-handling.html
  - https://github.com/project-chip/connectedhomeip
---

# Error Handling

## ESP-IDF Code

- Prefer `ESP_RETURN_ON_FALSE`, `ESP_RETURN_ON_ERROR`, `ESP_GOTO_ON_FALSE`, and `ESP_GOTO_ON_ERROR` in app and ESP-IDF component code.
- Use `ESP_RETURN_*` for argument checks and simple no-cleanup paths.
- Use `ESP_GOTO_*` when resources acquired earlier need one cleanup label.
- Keep cleanup labels short and deterministic; avoid multiple nested cleanup blocks.
- Log at the boundary that can add context. Do not spam logs inside tight polling paths.

## ESP-IDF Example

```c
esp_err_t driver_start(driver_t *driver)
{
    ESP_RETURN_ON_FALSE(driver, ESP_ERR_INVALID_ARG, TAG, "invalid driver");
    ESP_RETURN_ON_ERROR(driver_configure(driver), TAG, "configure driver failed");

    return ESP_OK;
}
```

## ESP-IDF Cleanup Example

```c
esp_err_t driver_create(driver_t **out_driver)
{
    esp_err_t ret = ESP_OK;
    driver_t *driver = calloc(1, sizeof(*driver));
    ESP_GOTO_ON_FALSE(driver, ESP_ERR_NO_MEM, err, TAG, "no memory for driver");

    ESP_GOTO_ON_ERROR(driver_init_bus(driver), err, TAG, "init bus failed");

    *out_driver = driver;
    return ESP_OK;

err:
    driver_destroy(driver);
    return ret;
}
```

## Matter / CHIP Code

- Prefer `VerifyOrReturn`, `VerifyOrReturnError`, `VerifyOrExit`, and related CHIP macros in Matter/CHIP code.
- Use `VerifyOrReturnError(condition, CHIP_ERROR_...)` for guard clauses in functions returning `CHIP_ERROR`.
- Use `VerifyOrReturn(condition)` for callback guards where ignoring is correct.
- Use `VerifyOrExit(condition, err = ...)` for shared cleanup.
- Avoid ESP-IDF error macros inside upstream-style CHIP modules unless the surrounding file already uses them.

## Matter Example

```cpp
CHIP_ERROR ReadThing(Thing *thing)
{
    VerifyOrReturnError(thing != nullptr, CHIP_ERROR_INVALID_ARGUMENT);
    VerifyOrReturnError(thing->IsReady(), CHIP_ERROR_INCORRECT_STATE);

    return thing->Read();
}
```

## Flattening Rules

- Validate inputs first.
- Return early for unsupported state.
- Keep happy path at the left margin.
- Use one cleanup label when cleanup is needed; otherwise return directly.
- Do not introduce a helper solely to avoid three straightforward lines.
