
package io.vertx.demo.react;

import io.vertx.rxcore.java.RxVertx;

import java.util.Random;

import org.vertx.java.core.json.JsonObject;

public class FakeDataGenerator
{
    private final static Random RANDOM = new Random();

    public FakeDataGenerator(final JsonObject config, final RxVertx rx)
    {
        final Long periodMills = config.getObject("data.generator").getLong("period.millis");
        final String metricsAddress = config.getObject("metrics").getString("address");

        rx.setPeriodic(periodMills).subscribe(timerId -> generateFakeData(metricsAddress, rx));
    }

    private void generateFakeData(final String address, final RxVertx rx)
    {
        // send a random number of events to simulate some variability
        final int numEvents = 1 + RANDOM.nextInt(10);

        for (int i = 0; i < numEvents; i++)
        {
            rx.eventBus().send(address,
                new JsonObject().putString("action", "mark").putString("name", "requests"));

            rx.eventBus().send(
                address,
                new JsonObject().putString("action", "update")
                    .putString("name", "responseTimes")
                    .putNumber("n", 25 + RANDOM.nextInt(475)));
        }
    }
}
