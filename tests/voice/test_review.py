"""The review page (T-101): it builds, carries coverage per actor and character, and the local server only accepts
choices for real line ids."""
import pytest

import review
import review_server
import voicelib as V


def test_page_builds_with_coverage(sandbox, tmp_path, monkeypatch):
    monkeypatch.setattr(V, "REVIEW_DIR", str(tmp_path / "rv"))
    monkeypatch.setattr(V, "WORK_DIR", str(tmp_path / "wk"))
    monkeypatch.setattr(review, "PAGE", str(tmp_path / "rv" / "index.html"))
    data = review.gather()
    assert data["total"] == len(data["rows"]) > 2000
    assert data["cov_actor"]["testactor"]["total"] == len([r for r in data["rows"] if r["char"] == "DUT"])
    assert "gl:DUT" in data["cov_char"] and "bs:sprocket" in data["cov_char"]
    html = open(review.build(), encoding="utf-8").read()
    assert "Coverage per actor" in html and "/*DATA*/null" not in html
    assert (tmp_path / "rv" / ".gdignore").exists()


def test_server_validates_selections():
    ids = {"DUT_RELOAD_01"}
    assert review_server.valid_selections({"DUT_RELOAD_01": {"take": "s1@2.00"}}, ids)["DUT_RELOAD_01"]["take"] == "s1@2.00"
    assert review_server.valid_selections({"DUT_RELOAD_01": "tts"}, ids)["DUT_RELOAD_01"]["take"] == "tts"
    with pytest.raises(ValueError):
        review_server.valid_selections({"../../etc": "x"}, ids)
    with pytest.raises(ValueError):
        review_server.valid_selections(["x"], ids)
