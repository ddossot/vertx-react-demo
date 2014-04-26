
package io.vertx.demo.react;

import static rx.Observable.from;
import static rx.Observable.zip;
import io.vertx.rxcore.java.RxVertx;
import io.vertx.rxcore.java.http.RxHttpServer;

import org.vertx.java.core.http.RouteMatcher;
import org.vertx.java.core.json.JsonArray;
import org.vertx.java.core.json.JsonObject;

import rx.Observable;

public class HttpServer
{
    private static final JsonObject METERS_BUS_REQUEST = new JsonObject().putString("action", "meters");
    private static final JsonObject HISTOGRAMS_BUS_REQUEST = new JsonObject().putString("action",
        "histograms");

    public HttpServer(final JsonObject conf, final RxVertx rx)
    {
        final RouteMatcher routeMatcher = newRouteMatcher(conf, rx);

        final RxHttpServer httpServer = rx.createHttpServer();
        httpServer.http().subscribe(req -> routeMatcher.handle(req));

        final Integer httpPort = conf.getObject("http").getInteger("port");
        final String httpHost = conf.getObject("http").getString("host");

        httpServer.coreHttpServer().listen(httpPort, httpHost);
    }

    private RouteMatcher newRouteMatcher(final JsonObject conf, final RxVertx rx)
    {
        final String metricsAddress = conf.getObject("metrics").getString("address");

        final RouteMatcher routeMatcher = new RouteMatcher();

        routeMatcher.get(
            "/api/sources",
            req -> {
                final Observable<JsonObject> meters = observeMetricsSource(metricsAddress,
                    METERS_BUS_REQUEST, "metrics", rx);

                final Observable<JsonObject> histograms = observeMetricsSource(metricsAddress,
                    HISTOGRAMS_BUS_REQUEST, "histograms", rx);

                zip(meters, histograms, (jo1, jo2) -> jo1.mergeIn(jo2)).subscribe(
                    sources -> req.response()
                        .putHeader("Content-Type", "application/json")
                        .end(sources.toString()),
                    error -> req.response().setStatusCode(500).end(error.getMessage()));
            });

        return routeMatcher;
    }

    private Observable<JsonObject> observeMetricsSource(final String metricsAddress,
                                                        final JsonObject busRequest,
                                                        final String sourceFieldName,
                                                        final RxVertx rx)
    {
        return rx.eventBus()
            .<JsonObject, JsonObject> send(metricsAddress, busRequest)
            .map(msg -> msg.body())
            .flatMap(jo -> from(jo.getFieldNames()))
            .filter(fn -> !fn.equals("status"))
            .reduce(new JsonArray(), (ja, fn) -> ja.add(fn))
            .map(ja -> new JsonObject().putArray(sourceFieldName, ja));
    }
}
