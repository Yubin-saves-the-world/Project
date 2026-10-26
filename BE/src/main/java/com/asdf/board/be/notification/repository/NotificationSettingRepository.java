package com.asdf.board.be.notification.repository;

import com.asdf.board.be.notification.entity.NotificationSetting;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationSettingRepository extends JpaRepository<NotificationSetting, NotificationSetting.Key> {

    List<NotificationSetting> findByIdUserId(Long userId);
}
