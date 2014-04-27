
package io.vertx.demo.react;

import static java.util.concurrent.TimeUnit.MILLISECONDS;
import static java.util.stream.Collectors.toSet;
import static rx.Observable.from;
import io.vertx.rxcore.java.RxVertx;

import org.vertx.java.core.json.JsonObject;

public class MetricsUpdatesRebroadcaster
{
    private static class Metrics
    {
        private final String type, name, addressPath;

        public Metrics(final JsonObject jo)
        {
            this.type = jo.getString("type");
            this.name = jo.getString("name");
            this.addressPath = type + "." + name;
        }

        public String type()
        {
            return type;
        }

        public String name()
        {
            return name;
        }

        public String addressPath()
        {
            return addressPath;
        }

        @Override
        public boolean equals(final Object obj)
        {
            return obj instanceof Metrics && ((Metrics) obj).addressPath.equals(addressPath);
        }

        @Override
        public int hashCode()
        {
            return addressPath.hashCode();
        }
    }

    public MetricsUpdatesRebroadcaster(final JsonObject config, final RxVertx rx)
    {
        final JsonObject metricsConfig = config.getObject("metrics");

        final String metricsAddress = metricsConfig.getString("address");
        final String metricsUpdatesAddress = metricsConfig.getString("updates.address");
        final long broadcastPeriodMillis = metricsConfig.getLong("broadcast.period.millis");
        final String broadcastBaseAddress = metricsConfig.getString("broadcast.base.address");

        rx.eventBus()
            .<JsonObject> registerLocalHandler(metricsUpdatesAddress)
            .buffer(broadcastPeriodMillis, MILLISECONDS)
            .flatMap(ms -> from(ms.stream().map(m -> new Metrics(m.body())).collect(toSet())))
            .subscribe(m -> fetchAndBroadcastMetrics(m, metricsAddress, broadcastBaseAddress, rx));
    }

    private void fetchAndBroadcastMetrics(final Metrics metrics,
                                          final String metricsAddress,
                                          final String broadcastBaseAddress,
                                          final RxVertx rx)
    {
        rx.eventBus()
            .<JsonObject, JsonObject> send(metricsAddress,
                new JsonObject().putString("action", metrics.type()))
            .map(msg -> msg.body().getObject(metrics.name()))
            .subscribe(
                v -> rx.coreVertx().eventBus().publish(broadcastBaseAddress + "." + metrics.addressPath(), v));
    }
}
