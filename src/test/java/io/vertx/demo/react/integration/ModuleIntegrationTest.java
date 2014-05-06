
package io.vertx.demo.react.integration;

import static io.netty.buffer.Unpooled.wrappedBuffer;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.CoreMatchers.notNullValue;
import static org.vertx.testtools.VertxAssert.assertThat;
import static org.vertx.testtools.VertxAssert.fail;
import static org.vertx.testtools.VertxAssert.testComplete;
import io.netty.buffer.ByteBuf;
import io.vertx.rxcore.java.http.RxHttpClient;

import org.junit.Test;
import org.vertx.java.core.buffer.Buffer;
import org.vertx.java.core.json.JsonObject;
import org.vertx.testtools.TestVerticle;

import rx.util.functions.Func2;

public class ModuleIntegrationTest extends TestVerticle
{
    private static Func2<Buffer, Buffer, Buffer> MERGE_BUFFERS = new Func2<Buffer, Buffer, Buffer>()
    {
        @Override
        public Buffer call(final Buffer b1, final Buffer b2)
        {
            final ByteBuf merged = wrappedBuffer(b1.getByteBuf(), b2.getByteBuf());
            return new Buffer(merged);
        }
    };

    @Override
    public void start()
    {
        initialize();

        container.deployModule(System.getProperty("vertx.modulename"), ar -> {
            assertThat(ar.succeeded(), is(true));
            assertThat(ar.result(), is(notNullValue()));

            // give some time for metrics to get collected
            vertx.setTimer(1000L, id -> startTests());
        });
    }

    @Test
    public void httpGetSources()
    {
        final RxHttpClient client = new RxHttpClient(vertx.createHttpClient()
            .setHost("localhost")
            .setPort(8080));

        client.getNow("/api/metrics/sources")
            .mapMany(resp -> resp.asObservable().reduce(MERGE_BUFFERS))
            .subscribe(buf -> {

                final JsonObject jsonObject = new JsonObject(buf.toString());
                assertThat(jsonObject.getFieldNames().isEmpty(), is(false));

                testOneSource(jsonObject, client);

            }, error -> fail(error.getMessage()));
    }

    private void testOneSource(final JsonObject sources, final RxHttpClient client)
    {
        final String type = sources.getFieldNames().iterator().next();
        final String name = sources.getArray(type).get(0);

        client.getNow("/api/metrics/" + type + "/" + name)
            .mapMany(resp -> resp.asObservable().reduce(MERGE_BUFFERS))
            .subscribe(buf -> {

                final JsonObject jsonObject = new JsonObject(buf.toString());
                assertThat(jsonObject.getFieldNames().isEmpty(), is(false));

            }, error -> fail(error.getMessage()), () -> testComplete());
    }

    @Test
    public void httpGetWebHomePage()
    {
        final RxHttpClient client = new RxHttpClient(vertx.createHttpClient()
            .setHost("localhost")
            .setPort(8080));

        client.getNow("/").mapMany(resp -> resp.asObservable().reduce(MERGE_BUFFERS)).subscribe(buf -> {

            assertThat(buf.toString().contains("</html>"), is(true));

        }, error -> fail(error.getMessage()), () -> testComplete());
    }
}
