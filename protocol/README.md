# Protocol

Client/server protocol definitions live here.

```text
protocol/
  schemas/      Source protocol schemas.
  generated/    Generated protocol bindings.
  docs/         Protocol notes and compatibility policy.
```

Keep protocol ownership outside individual clients and servers so all implementations share the same message version.

Candidate formats:

- JSON Schema for early tooling and readability.
- Protocol Buffers or FlatBuffers when binary compatibility, code generation, or higher throughput becomes necessary.
