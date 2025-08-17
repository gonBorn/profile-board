FROM eclipse-temurin:21-jdk
WORKDIR /app
COPY . .
RUN ./gradlew build --no-daemon
RUN cp build/libs/profile-board-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
