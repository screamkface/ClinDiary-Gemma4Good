from __future__ import annotations

from io import BytesIO
import html

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import ListFlowable, ListItem, Paragraph, SimpleDocTemplate, Spacer


class ReportPdfBuilder:
    def build(self, *, title: str, subtitle: str, sections: list[tuple[str, list[str]]]) -> bytes:
        buffer = BytesIO()
        document = SimpleDocTemplate(
            buffer,
            pagesize=A4,
            leftMargin=40,
            rightMargin=40,
            topMargin=40,
            bottomMargin=40,
        )
        styles = getSampleStyleSheet()
        story = [
            Paragraph(html.escape(title), styles["Title"]),
            Spacer(1, 12),
            Paragraph(html.escape(subtitle), styles["BodyText"]),
            Spacer(1, 18),
        ]

        for heading, items in sections:
            story.append(Paragraph(html.escape(heading), styles["Heading2"]))
            story.append(Spacer(1, 6))
            if items:
                story.append(
                    ListFlowable(
                        [
                            ListItem(
                                Paragraph(html.escape(item).replace("\n", "<br/>"), styles["BodyText"])
                            )
                            for item in items
                        ],
                        bulletType="bullet",
                        leftIndent=14,
                    )
                )
            else:
                story.append(Paragraph("Nessun dato disponibile.", styles["BodyText"]))
            story.append(Spacer(1, 14))

        document.build(story)
        return buffer.getvalue()
