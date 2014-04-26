
package io.vertx.demo.react.integration.java;

import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.CoreMatchers.notNullValue;
import static org.junit.Assert.fail;
import static org.vertx.testtools.VertxAssert.assertThat;
import static org.vertx.testtools.VertxAssert.testComplete;
import io.vertx.rxcore.RxSupport;
import io.vertx.rxcore.java.http.RxHttpClient;

import org.junit.Test;
import org.vertx.java.core.json.JsonObject;
import org.vertx.testtools.TestVerticle;

public class ModuleIntegrationTest extends TestVerticle
{
    @Override
    public void start()
    {
        initialize();

        container.deployModule(System.getProperty("vertx.modulename"), ar -> {
            assertThat(ar.succeeded(), is(true));
            assertThat(ar.result(), is(notNullValue()));
            startTests();
        });
    }

    @Test
    public void httpGetSources()
    {
        final RxHttpClient client = new RxHttpClient(vertx.createHttpClient()
            .setHost("localhost")
            .setPort(8080));

        client.getNow("/api/sources")
            .mapMany(resp -> resp.asObservable().reduce(RxSupport.mergeBuffers))
            .subscribe(buf -> {
                final JsonObject jsonObject = new JsonObject(buf.toString());
                assertThat(jsonObject.getFieldNames().isEmpty(), is(false));
            }, error -> fail(error.getMessage()), () -> testComplete());
    }
}
