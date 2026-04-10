# UI Wireframe (Observe -> Decide -> Act -> Verify)

## Panel 1: Observe (top priority)
- Growbox live values: temperature, humidity, fan state.
- Service badges: OpenClaw, Home Assistant, Mosquitto, Pi-hole.
- Last successful sync timestamp.

## Panel 2: Decide
- Highlight anomalies (threshold breaches).
- Show recommended actions based on current state.
- Show confidence level for recommendation.

## Panel 3: Act
- Action buttons with clear labels and confirmations.
- Disable risky actions when dependencies are unhealthy.
- Record action request IDs for tracing.

## Panel 4: Verify
- Real-time action status updates.
- Last 10 actions timeline with outcome and latency.
- Quick retry button for retryable failures.

## Responsive Baseline
- 320px: stacked full-width controls.
- 480-768px: compact cards with two-column metrics.
- >=1200px: full dashboard with side diagnostics.
