# # Part 3
# FROM eclipse-temurin:21 AS builder
# WORKDIR /workspace
# ARG JAR_FILE=build/libs/*.jar
# COPY ${JAR_FILE} catalog-service.jar
# # Extract layers
# RUN java -Djarmode=tools -jar catalog-service.jar extract --layers --launcher

# Stage 1: Build the application
FROM gradle:8.5-jdk21 AS builder
WORKDIR /app
COPY build.gradle settings.gradle ./
COPY src ./src
RUN gradle bootJar --no-daemon

# Stage 2: Create the runtime image
FROM eclipse-temurin:21-jre
COPY --from=builder /app/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]

# FROM eclipse-temurin:21
# RUN useradd spring
# USER spring
# WORKDIR workspace
# # Copy layers separately
# COPY --from=builder /app/catalog-service/dependencies ./
# COPY --from=builder /app/catalog-service/spring-boot-loader ./
# COPY --from=builder /app/catalog-service/snapshot-dependencies ./
# COPY --from=builder /app/catalog-service/application ./
# #  Use JarLauncher to launch extracted jar
# ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]