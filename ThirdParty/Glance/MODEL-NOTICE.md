# Face recognition model — separate terms

`Resources/FaceUnlock/ArcFace.mlpackage` is the converted InsightFace
`w600k_mbf` model supplied by jonnyoo/glance at commit
`b97f521397ec1197ba17768ba797cae1e628848d`. Its input is a 112 × 112 RGB face;
its output is a 512-element embedding. Build-time compilation does not
change the weights. Conversion provenance:
https://github.com/jonnyoo/glance/blob/b97f521397ec1197ba17768ba797cae1e628848d/tools/convert_arcface.py

InsightFace states that its pretrained models are for **non-commercial
research purposes only**. The MIT license on Glance's code and the GPL on
Vorssaint's code do not relicense these weights. This fork's bundled Face
Unlock implementation is experimental, for evaluation under those terms.
A general-purpose or commercial distribution needs appropriately licensed
weights and corresponding validation before release.

Authoritative model terms:
https://github.com/deepinsight/insightface/blob/master/python-package/README.md
https://github.com/deepinsight/insightface/blob/master/python-package/docs/model_zoo.md

The feature runs entirely locally; no model or biometric data is downloaded
or uploaded by the app at runtime.
