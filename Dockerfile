# 第一阶段用 JDK 构建 jar，
# 第二阶段用 JRE 只保留 jar 文件。
# 这样最终镜像只包含运行环境和 app.jar，体积会显著减小，更适合生产部署

FROM eclipse-temurin:21-jdk AS builder
WORKDIR /app
COPY . .
RUN ./gradlew build --no-daemon

FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app
COPY --from=builder /app/build/libs/profile-board-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
