package com.asdf.board.be.partner.repository;

import com.asdf.board.be.partner.entity.Partner;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PartnerRepository extends JpaRepository<Partner, Long> {
}
