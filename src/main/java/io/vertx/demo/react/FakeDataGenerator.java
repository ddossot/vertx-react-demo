
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

    private final RxVertx rx;
    private final String metricsAddress, metricsUpdatesAddress;
    private final int minMillis, maxMillis, burstEveryMillis, burstSize;

    private volatile long nextBurstTimestamp;

    public FakeDataGenerator(final JsonObject config, final RxVertx rx)
    {
        this.rx = rx;

        metricsAddress = config.getObject("metrics").getString("address");
        metricsUpdatesAddress = config.getObject("metrics").getString("updates.address");

        minMillis = config.getObject("data.generator").getInteger("min.millis");
        maxMillis = config.getObject("data.generator").getInteger("max.millis");
        burstEveryMillis = config.getObject("data.generator").getInteger("burst.every.millis");
        burstSize = config.getObject("data.generator").getInteger("burst.size");

        setNextBurstTimeStamp();

        scheduleNextEvent();
    }

    private void scheduleNextEvent()
    {
        final int waitMillis = minMillis + RANDOM.nextInt(maxMillis - minMillis);

        rx.setTimer(waitMillis).subscribe(timerId -> {
            generateFakeData();
            scheduleNextEvent();
        });
    }

    private void generateFakeData()
    {
        final long timestamp = System.currentTimeMillis();
        final boolean shouldBurst = timestamp >= nextBurstTimestamp;

        final int eventCount = shouldBurst ? burstSize : 1;
        for (int i = 0; i < eventCount; i++)
        {
            sendFakeDataEvents();
        }

        if (shouldBurst)
        {
            setNextBurstTimeStamp();
        }
    }

    private void sendFakeDataEvents()
    {
        rx.eventBus()
            .send(metricsAddress, REQUESTS_METER_MARK_MESSAGE)
            .subscribe(m -> rx.eventBus().send(metricsUpdatesAddress, REQUESTS_METER_UPDATED_MESSAGE));

        final JsonObject responseTimesUpdateMessage = new JsonObject().putString("action", "update")
            .putString("name", "responseTimes")
            .putNumber("n", 25 + RANDOM.nextInt(475));

        rx.eventBus()
            .send(metricsAddress, responseTimesUpdateMessage)
            .subscribe(
                m -> rx.eventBus().send(metricsUpdatesAddress, RESPONSE_TIMES_HISTOGRAM_UPDATED_MESSAGE));
    }

    private void setNextBurstTimeStamp()
    {
        nextBurstTimestamp = System.currentTimeMillis() + burstEveryMillis;
    }
}
