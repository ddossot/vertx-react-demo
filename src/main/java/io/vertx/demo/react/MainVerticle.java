
package io.vertx.demo.react;

import io.vertx.rxcore.java.RxVertx;

import org.vertx.java.core.buffer.Buffer;
import org.vertx.java.core.json.JsonObject;
import org.vertx.java.platform.Verticle;

public class MainVerticle extends Verticle
{
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

        container.deployModule("com.bloidonia~mod-metrics~1.0.1", config.getObject("metrics"), ar -> {
            if (ar.succeeded())
            {
                start(config);
            }
            else
            {
                container.logger().fatal("Failed to deploy metrics module", ar.cause());
            }
        });
    }

    private void start(final JsonObject config)
    {
        final RxVertx rx = new RxVertx(vertx);

        new FakeDataGenerator(config, rx);
        new HttpServer(config, rx);

        container.logger().info("Vert.x React Demo is running");
    }
}
