# C and C++ conventions

Apply these conventions to application-owned ESP-IDF and Matter code. Use C's procedural programming model with selected C++ features for type safety and deterministic cleanup. Preserve the project's language standard, public ABI, and required SDK interfaces. Do not rewrite vendor or generated code to fit this dialect.

General naming, extraction thresholds, layout, and comment quality belong to [Coding style](../coding-style/SKILL.md). The rules here specify language choices and SDK-facing behavior.

## Functions, structs, and classes

- Default to free functions, plain structs, enums, and direct calls. Use a class when it owns a resource or enforces an invariant, not merely to collect functions.
- Use `enum class` for application C++ states and discrete choices. Use ordinary enums where C compatibility requires them. Choose an explicit underlying width only when storage, ABI, or protocol requirements justify it.
- For simple alternative payloads, prefer a tag and a union of trivially managed members over introducing `std::variant`. Keep the tag consistent with the active member. Do not manually manage nontrivial union members merely to avoid a library type; reconsider the representation.
- Implement SDK-required virtual interfaces and delegates. Do not introduce application inheritance hierarchies, `friend` declarations, CRTP, or policy-based template frameworks by default.
- Consume ordinary standard-library and SDK templates when they fit. Do not build a generic framework around a concrete operation or use operator overloading to hide effects.

## Types and expressions

- Spell consequential types explicitly, especially ownership, numeric width, and SDK error types. Allow `auto` when the initializer makes the type obvious or an unwieldy iterator type obscures the operation.
- Use `const` for read-only access. In C++, prefer a reference for a required borrowed object and a pointer for an optional object or an API that requires pointers. Neither extends the object's lifetime.
- Use `nullptr` in C++. Prefer explicit C++ casts over C-style casts; a cast does not establish range safety, alignment, or a valid object lifetime. Reserve reinterpretation for an actual representation boundary with those guarantees established.
- Use fixed-width integers for wire and storage formats that require them, and `size_t` for in-memory lengths and indexes where the API uses it. Check narrowing conversions. Do not serialize a struct's raw memory and assume portable padding, endianness, or enum representation.
- Prefer `constexpr` constants to object-like macros in C++. Use the project's established constant conventions in C.

## Ownership and initialization

- Store an owned object directly when its size and lifetime permit. Use `std::unique_ptr` when dynamic ownership is necessary. Raw pointers normally borrow; document explicit ownership transfer in C and SDK APIs.
- Match allocation and release APIs. A default `unique_ptr` deleter is not suitable for an SDK allocation that requires a different release function. Inspect SDK owner types rather than assuming standard move or copy behavior.
- Do not introduce `std::shared_ptr` by default. Shared ownership must correspond to a real lifetime requirement, not conceal an unclear owner or missing cancellation contract.
- Use deterministic RAII for cleanup, including early returns. Cleanup must run in a context where the release API is valid. A destructor must not silently launch asynchronous cleanup that still depends on the destroyed object.
- Keep fallible hardware and SDK initialization in an explicit operation returning the subsystem's error type. Constructors for simple value types and local resource guards remain appropriate.
- Avoid global or static objects whose constructors or destructors allocate, acquire locks, create tasks, or access hardware. Constant initialization and trivial zero-initialized storage are suitable; resource startup and shutdown should be explicit.
- Use established SDK buffers, spans, and containers when their ownership, capacity, and failure behavior fit. A span is borrowed, not owned. Verify implicit allocation and failure behavior before adding a standard-library container to an embedded path.

## Errors and callbacks

- Use the subsystem's existing `esp_err_t`, `CHIP_ERROR`, or protocol status. Do not add custom `Result<T>` types, error hierarchies, or exception-based adapters by default. Follow the SDK's output-parameter conventions and specify output validity on failure.
- Do not enable exceptions or RTTI merely to use a convenience abstraction. Respect the target's build configuration and check how allocation failure behaves without exceptions.
- Prefer named callbacks for asynchronous lifecycle work. A short lambda is suitable when its captures and lifetime remain visible. Do not use capture-all `[&]` or `[=]` for queued or asynchronous callbacks; capturing `this` explicitly still requires an owner-lifetime guarantee.
- Use the SDK's callback and context representation rather than introducing `std::function` by default. Explain any necessary allocation, indirect dispatch, or captured ownership.
- Use SDK error macros according to their control-flow and cleanup contract. The concrete ESP-IDF and CHIP conventions are in [ESP-IDF](ESP-IDF.md) and [Matter and CHIP](MATTER.md).

## Headers and namespaces

- Put the corresponding header first in an implementation file. Separate project headers, standard-library headers, and SDK/dependency headers into groups, following the repository's order and delimiter conventions.
- Keep public headers self-contained. Follow the repository's include-guard convention and retain required license headers.
- Let public C-compatible headers own their `extern "C"` guards. In C++ definitions, include that header instead of redundantly wrapping definitions whose declarations already establish C linkage.
- Keep namespaces shallow. Do not put `using namespace` directives in headers. Restrained use after the include block in implementation files is acceptable when it matches nearby SDK code and avoids excessive qualification.
- Use anonymous namespaces for file-local C++ definitions when they fit the repository's build model. Do not impose an amalgamation-specific ban on ordinary translation units.
- Close nontrivial namespace blocks with `} // namespace name`, or `} // namespace` for an anonymous namespace, using the repository's spacing convention.

## Macros and conditional compilation

Prefer a function, `constexpr`, or scoped enum over a new application macro when it expresses the same contract. Keep SDK macros required for logging, configuration, propagation, placement, and registration.

For a non-obvious macro, document relevant repeated argument evaluation, hidden `return` or `goto`, cleanup requirements, execution context, and memory-placement restrictions near its definition or first consequential use.

Label the closing directives of long or nested conditional-compilation blocks with the opening condition. Add a branch-condition comment to a distant `#else`. An `#elif` already names its own condition; add context only when earlier branches make its meaning unclear.

```cpp
#if CONFIG_DEVICE_FEATURE
	// Feature-specific declarations or implementation.
#else // !CONFIG_DEVICE_FEATURE
	// Implementation without the feature.
#endif // CONFIG_DEVICE_FEATURE
```

For a multi-branch chain, an `#else` means none of the preceding conditions matched. Do not label it as merely the inverse of the last `#elif`. Keep comments accurate when conditions change. Short, obvious blocks need no redundant annotation.

These conventions do not require a lint tool. Verify them while reviewing the affected code and its enabled configuration branches.
