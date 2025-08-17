package io.github.gonborn.profileboard;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HeartbeatController {

    @GetMapping("/heartbeat")
    public String heartbeat() {
        return "OK";
    }
}

