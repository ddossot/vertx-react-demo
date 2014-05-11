
package io.vertx.demo.react;

import io.vertx.rxcore.java.RxVertx;

import org.vertx.java.core.buffer.Buffer;
import org.vertx.java.core.json.JsonObject;
import org.vertx.java.platform.Verticle;

public class MainVerticle extends Verticle
{
    private static final String METRICS_MODULE = "com.bloidonia~mod-metrics~1.0.1";

    @Override
    public void start()
    {
        vertx.fileSystem().readFile("config.json", ar -> {
            if (ar.succeeded())
            {
                parseConfigAndStart(ar.result());
            }
            else
            {
                container.logger().fatal("Failed to load configuration", ar.cause());
            }
        });
    }

    private void parseConfigAndStart(final Buffer buffer)
    {
        final JsonObject config = new JsonObject(buffer.toString());

        container.deployModule(
            METRICS_MODULE,
            config.getObject("metrics"),
            ar -> {
                if (ar.succeeded())
                {
                    container.logger().fatal("Deployed: " + METRICS_MODULE + " with id: " + ar.result(),
                        ar.cause());

                    start(config);
                }
                else
                {
                    container.logger().fatal("Failed to deploy: " + METRICS_MODULE, ar.cause());
                }
            });
    }

    private void start(final JsonObject config)
    {
        final RxVertx rx = new RxVertx(vertx);

        new FakeDataGenerator(config, rx);
        new MetricsUpdatesRebroadcaster(config, rx);
        new HttpServer(config, rx);
        final String host = config.getObject("http").getString("host");
        final Integer port = config.getObject("http").getInteger("port");

        container.logger().info(String.format("Vert.x/Rx/React demo running on %s:%d", host, port));
    }
}
