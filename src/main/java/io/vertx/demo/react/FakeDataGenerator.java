
package io.vertx.demo.react;

import io.vertx.rxcore.java.RxVertx;

import java.util.Random;

import org.vertx.java.core.json.JsonObject;

public class FakeDataGenerator
{
    private static final JsonObject REQUESTS_METER_MARK_MESSAGE = new JsonObject().putString("action", "mark")
        .putString("name", "requests");

    private static final JsonObject REQUESTS_METER_UPDATED_MESSAGE = new JsonObject().putString("type",
        "meters").putString("name", "requests");

    private static final JsonObject RESPONSE_TIMES_HISTOGRAM_UPDATED_MESSAGE = new JsonObject().putString(
        "type", "histograms").putString("name", "responseTimes");

    private final static Random RANDOM = new Random();

    public FakeDataGenerator(final JsonObject config, final RxVertx rx)
    {
        final String metricsAddress = config.getObject("metrics").getString("address");
        final String metricsUpdatesAddress = config.getObject("metrics").getString("updates.address");

        final int minMillis = config.getObject("data.generator").getInteger("min.millis");
        final int maxMillis = config.getObject("data.generator").getInteger("max.millis");

        scheduleNextEvent(metricsAddress, metricsUpdatesAddress, minMillis, maxMillis, rx);
    }

    private void scheduleNextEvent(final String metricsAddress,
                                   final String metricsUpdatesAddress,
                                   final int minMillis,
                                   final int maxMillis,
                                   final RxVertx rx)
    {
        final int waitMillis = minMillis + RANDOM.nextInt(maxMillis - minMillis);

        rx.setTimer(waitMillis).subscribe(timerId -> {
            generateFakeData(metricsAddress, metricsUpdatesAddress, rx);
            scheduleNextEvent(metricsAddress, metricsUpdatesAddress, minMillis, maxMillis, rx);
        });
    }

    private void generateFakeData(final String address, final String metricsUpdatesAddress, final RxVertx rx)
    {
        rx.eventBus()
            .send(address, REQUESTS_METER_MARK_MESSAGE)
            .subscribe(m -> rx.eventBus().send(metricsUpdatesAddress, REQUESTS_METER_UPDATED_MESSAGE));

        final JsonObject responseTimesUpdateMessage = new JsonObject().putString("action", "update")
            .putString("name", "responseTimes")
            .putNumber("n", 25 + RANDOM.nextInt(475));

        rx.eventBus()
            .send(address, responseTimesUpdateMessage)
            .subscribe(
                m -> rx.eventBus().send(metricsUpdatesAddress, RESPONSE_TIMES_HISTOGRAM_UPDATED_MESSAGE));
    }
}
